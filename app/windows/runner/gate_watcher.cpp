#include "gate_watcher.h"

#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cctype>
#include <cwctype>

namespace {

const char kChannel[] = "guard/gate";

std::string Utf8(const std::wstring& w) {
  if (w.empty()) return {};
  int n = WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, nullptr, 0, nullptr, nullptr);
  std::string s(n > 0 ? n - 1 : 0, '\0');
  if (n > 0) WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, s.data(), n, nullptr, nullptr);
  return s;
}

long long AsInt64(const flutter::EncodableValue& v) {
  if (auto p = std::get_if<int64_t>(&v)) return *p;
  if (auto p = std::get_if<int32_t>(&v)) return *p;
  if (auto p = std::get_if<double>(&v)) return static_cast<long long>(*p);
  return 0;
}

std::string AsString(const flutter::EncodableValue& v) {
  if (auto p = std::get_if<std::string>(&v)) return *p;
  return {};
}

const flutter::EncodableValue* Get(const flutter::EncodableMap& m, const char* key) {
  auto it = m.find(flutter::EncodableValue(key));
  return it == m.end() ? nullptr : &it->second;
}

}  // namespace

GateWatcher::GateWatcher(flutter::BinaryMessenger* messenger, HWND host) : host_(host) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, kChannel, &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleCall(call, std::move(result));
  });
  SetTimer(host_, kTimerId, 1000, nullptr);
}

GateWatcher::~GateWatcher() {
  KillTimer(host_, kTimerId);
  if (channel_) channel_->SetMethodCallHandler(nullptr);
}

long long GateWatcher::NowMs() {
  FILETIME ft;
  GetSystemTimeAsFileTime(&ft);
  ULARGE_INTEGER u;
  u.LowPart = ft.dwLowDateTime;
  u.HighPart = ft.dwHighDateTime;
  // 100ns intervals since 1601 -> ms since 1970.
  return static_cast<long long>((u.QuadPart - 116444736000000000ULL) / 10000ULL);
}

void GateWatcher::HandleCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& name = call.method_name();
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());

  if (name == "listApps") {
    flutter::EncodableList apps;
    const std::pair<const char*, const char*> known[] = {
        {"terminal64.exe", "MetaTrader 5"},
        {"terminal.exe", "MetaTrader 4"},
        {"ctrader.exe", "cTrader"},
    };
    for (const auto& [id, label] : known) {
      apps.push_back(flutter::EncodableMap{
          {flutter::EncodableValue("id"), flutter::EncodableValue(id)},
          {flutter::EncodableValue("label"), flutter::EncodableValue(label)},
          // Installed is unknowable without scanning disks; the gate works on process name anyway.
          {flutter::EncodableValue("installed"), flutter::EncodableValue(true)},
      });
    }
    result->Success(flutter::EncodableValue(apps));
    return;
  }

  if (name == "scheduleWindows") {
    windows_.clear();
    gated_.clear();
    if (args) {
      if (auto* list = Get(*args, "windows")) {
        if (auto* l = std::get_if<flutter::EncodableList>(list)) {
          for (const auto& item : *l) {
            auto* m = std::get_if<flutter::EncodableMap>(&item);
            if (!m) continue;
            GateWindowSpec w;
            if (auto* v = Get(*m, "windowId")) w.id = AsString(*v);
            if (auto* v = Get(*m, "opensAtMs")) w.opens_at_ms = AsInt64(*v);
            if (auto* v = Get(*m, "closesAtMs")) w.closes_at_ms = AsInt64(*v);
            if (auto* v = Get(*m, "instrument")) w.instrument = AsString(*v);
            if (auto* v = Get(*m, "events")) w.events = AsString(*v);
            windows_.push_back(w);
          }
        }
      }
      if (auto* pk = Get(*args, "gatedPackages")) {
        if (auto* l = std::get_if<flutter::EncodableList>(pk)) {
          for (const auto& item : *l) {
            auto s = AsString(item);
            std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
            if (!s.empty()) gated_.insert(s);
          }
        }
      }
      if (auto* p = Get(*args, "protection")) protection_ = AsString(*p);
    }
    result->Success(flutter::EncodableValue(static_cast<int64_t>(windows_.size())));
    return;
  }

  if (name == "setViewingUntil") {
    if (args) {
      if (auto* v = Get(*args, "untilMs")) viewing_until_ms_ = AsInt64(*v);
    }
    result->Success();
    return;
  }

  if (name == "raiseGate") {
    HWND target = nullptr;
    if (args) {
      if (auto* v = Get(*args, "handle")) target = reinterpret_cast<HWND>(static_cast<intptr_t>(AsInt64(*v)));
    }
    RaiseGate(target);
    result->Success();
    return;
  }

  if (name == "lowerGate") {
    LowerGate();
    result->Success();
    return;
  }

  if (name == "stayOut") {
    if (args) {
      if (auto* v = Get(*args, "handle")) {
        HWND target = reinterpret_cast<HWND>(static_cast<intptr_t>(AsInt64(*v)));
        if (target && IsWindow(target)) ShowWindow(target, SW_MINIMIZE);
      }
    }
    LowerGate();
    result->Success();
    return;
  }

  if (name == "drainJournal") {
    // The Windows gate is a Flutter screen; Dart records outcomes directly.
    result->Success(flutter::EncodableValue(flutter::EncodableList{}));
    return;
  }

  result->NotImplemented();
}

std::string GateWatcher::ForegroundProcessName(HWND* out_hwnd) {
  HWND fg = GetForegroundWindow();
  if (out_hwnd) *out_hwnd = fg;
  if (!fg) return {};
  DWORD pid = 0;
  GetWindowThreadProcessId(fg, &pid);
  if (!pid) return {};
  HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (!h) return {};
  wchar_t buf[MAX_PATH];
  DWORD size = MAX_PATH;
  std::wstring name;
  if (QueryFullProcessImageNameW(h, 0, buf, &size)) {
    std::wstring full(buf, size);
    auto slash = full.find_last_of(L"\\/");
    name = slash == std::wstring::npos ? full : full.substr(slash + 1);
    std::transform(name.begin(), name.end(), name.begin(), [](wchar_t c) { return static_cast<wchar_t>(std::towlower(c)); });
  }
  CloseHandle(h);
  return Utf8(name);
}

void GateWatcher::Tick() {
  if (windows_.empty() || protection_ == "warn-only") return;
  const long long now = NowMs();
  if (now < viewing_until_ms_) return;

  const GateWindowSpec* open = nullptr;
  for (const auto& w : windows_) {
    if (now >= w.opens_at_ms && now < w.closes_at_ms) {
      open = &w;
      break;
    }
  }
  if (!open) return;

  HWND fg = nullptr;
  const std::string proc = ForegroundProcessName(&fg);
  if (proc.empty() || fg == host_ || gated_.count(proc) == 0) return;
  if (now - last_shown_ms_ < 1500) return;
  last_shown_ms_ = now;

  channel_->InvokeMethod(
      "gateTriggered",
      std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
          {flutter::EncodableValue("windowId"), flutter::EncodableValue(open->id)},
          {flutter::EncodableValue("handle"), flutter::EncodableValue(static_cast<int64_t>(reinterpret_cast<intptr_t>(fg)))},
          {flutter::EncodableValue("process"), flutter::EncodableValue(proc)},
      }));
}

void GateWatcher::RaiseGate(HWND target) {
  // Put the Flutter window on the trading app's monitor, full size, topmost.
  HMONITOR mon = MonitorFromWindow(target && IsWindow(target) ? target : host_, MONITOR_DEFAULTTONEAREST);
  MONITORINFO mi{sizeof(MONITORINFO)};
  RECT rc{0, 0, 1280, 800};
  if (GetMonitorInfoW(mon, &mi)) rc = mi.rcMonitor;

  ShowWindow(host_, SW_RESTORE);
  SetWindowPos(host_, HWND_TOPMOST, rc.left, rc.top, rc.right - rc.left, rc.bottom - rc.top,
               SWP_SHOWWINDOW);

  // Windows only lets the last-input thread take the foreground. Borrow it.
  DWORD fg_thread = GetWindowThreadProcessId(GetForegroundWindow(), nullptr);
  DWORD me = GetCurrentThreadId();
  if (fg_thread && fg_thread != me) AttachThreadInput(fg_thread, me, TRUE);
  SetForegroundWindow(host_);
  BringWindowToTop(host_);
  SetFocus(host_);
  if (fg_thread && fg_thread != me) AttachThreadInput(fg_thread, me, FALSE);
}

void GateWatcher::LowerGate() {
  SetWindowPos(host_, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
  ShowWindow(host_, SW_MINIMIZE);
}
