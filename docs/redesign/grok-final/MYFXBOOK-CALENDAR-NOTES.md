# Myfxbook economic calendar notes

Research checked 29 September 2026 (UK time).

## Impact colours and markers

Myfxbook’s calendar uses an impact badge as well as colour:

- **High** — red.
- **Medium** — orange/amber in the captured Myfxbook UI (use **yellow** for the redesign mapping requested here).
- **Low** — lime/green.
- **None/no impact** — grey.

The official help describes four levels (none, low, medium, high), but Myfxbook does not publish a clear colour legend. The colours above are therefore a visual observation, cross-checked against a 2024 screenshot of the live table, not a promise of a stable brand token.

Other visible icons/markers:

- Country flag plus a three-letter currency code identifies the affected country/currency.
- A small speaker marker appears beside speech events.
- A bell at the row’s right edge is used for an event reminder/notification in the captured UI; Myfxbook’s help confirms that individual event reminders are supported.
- Calendar, search, and information icons support date selection, text search, and help. Holiday/special-event symbols also appear, but their exact meanings are not documented in the official help, so they should have tooltips in a redesign.

## What a row shows

The table is grouped by date and normally shows: **date/time**, **time left** countdown, **country flag**, **currency**, **event name**, **impact**, **previous**, **consensus** (forecast), and **actual**. Released values can be visually highlighted; revised previous values are indicated (the review says the original value is available on hover/click). A `Show More` control loads additional rows.

Clicking an event opens fuller detail: explanation/definition, data source, next release information, and historical values where available. The broader detail view may also include a historical actual-vs-forecast chart, a related currency-pair price chart, sentiment, and related news.

## Filters and default behaviour

The configuration control at the top right supports filtering by **currency**, **impact**, and **region/country**. The page also supports keyword search (event, currency, country, or impact), quick ranges (Yesterday, Today, Tomorrow, This Week, Next Week), custom date ranges, reminders/live notifications, and CSV/XML export. The official help confirms currency, impact, and region/country filters plus reminders and export.

A universal default impact selection is **not documented reliably**. A captured table shows None, Low, Medium, and High together and has All/None controls, so the safest parity assumption is “all impact levels visible initially”; treat that as an implementation choice, not a confirmed Myfxbook contract. Preserve a user’s selection when possible.

## Guard / colour rule for Elite redesign

Jamie’s earlier guard banned green for an “all clear” state. The newer requirement is specifically **low news impact = green, medium = yellow, high = red**. Resolve the conflict by scoping green to the calendar only:

> **Green is allowed only for low-impact calendar dots/badges/rows. Never use green for clear, success, healthy, complete, or no-alert states.**

For consistency, use grey (or the neutral surface colour) for no-impact/none, yellow/amber for medium, and red for high. Do not let the calendar’s low-impact green leak into general status semantics.

## Sources

- Myfxbook Help, “Economic Calendar” (updated 21 Mar 2024): https://www.myfxbook.com/help/knowledge-base/economic-calendar/
- Myfxbook blog, “Economic Calendar – a must have for traders”: https://www.myfxbook.com/blog/2021/02/15/economic-calendar-a-must-have-for-traders/
- Myfxbook calendar page: https://www.myfxbook.com/forex-economic-calendar
- Datawookie, “Economic Calendar” (2024-10-02; includes a captured Myfxbook table and exported column names): https://datawookie.dev/blog/2024-10-02-economic-calendar/
- EarnForex, “Top 11 Forex Calendars in 2026” (Myfxbook comparison: no official legend, filters, detail view, revisions, export): https://www.earnforex.com/guides/top-forex-calendars/

Note: Myfxbook pages were Cloudflare-blocked to the fetcher during this check, so exact current styling and defaults should be re-verified in the live UI before shipping.
