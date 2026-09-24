#ifndef RUNNER_GATE_WATCHER_H_
#define RUNNER_GATE_WATCHER_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <set>
#include <string>
#include <vector>

// The Windows half of the Soft gate (docs/SOFT-GATE.md). Polls the foreground
// window once a second while a window is open; when a gated process comes to
// the front it tells Dart, which shows the gate screen in this same Flutter
// window, raised over the trading app's monitor. Nothing touches the trading
// app beyond reading its process name and, on "Stay out", minimising it.
struct GateWindowSpec {
  std::string id;
  long long opens_at_ms = 0;
  long long closes_at_ms = 0;
  std::string instrument;
  std::string events;
};

class GateWatcher {
 public:
  static constexpr UINT_PTR kTimerId = 0x6A7E;

  GateWatcher(flutter::BinaryMessenger* messenger, HWND host);
  ~GateWatcher();

  // Called from the host window's WM_TIMER.
  void Tick();

 private:
  void HandleCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  std::string ForegroundProcessName(HWND* out_hwnd);
  void RaiseGate(HWND target);
  void LowerGate();
  static long long NowMs();

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND host_;
  std::vector<GateWindowSpec> windows_;
  std::set<std::string> gated_{"terminal64.exe"};
  std::string protection_ = "soft-gate";
  long long viewing_until_ms_ = 0;
  long long last_shown_ms_ = 0;
  WINDOWPLACEMENT saved_placement_{};
  bool have_saved_placement_ = false;
};

#endif  // RUNNER_GATE_WATCHER_H_
