# Calendar vendors

The brief says cost this before build, and evaluate at least two. Findings from 23
Sep 2026, from public pricing pages and third-party comparisons. Get written quotes
before signing anything; these numbers are for choosing who to call.

| Vendor | Public price | Redistribution in an app | Notes |
|---|---|---|---|
| Trading Economics | Standard $149 a month, Professional $299 a month, billed yearly | Custom quote, adjusted for features, volume and distribution | Global calendar with impact ratings. Flat cost is what a free app wants |
| FXMacroData | Individual $25 a month. Commercial redistribution $25 a month minimum for the first 250 measured users, then $10 per 100 users a month | Built into the commercial plan | FX-focused, exact timestamps, source labels. Cost tracks user count |
| FXStreet | Not published, sales only | Licensed product for brokers and publishers | Broker-grade. Expect the highest number |
| Finnhub | Economic data from $50 a month | Unclear for display in a consumer app | Calendar quality for red-folder use unproven |
| Financial Modeling Prep | Subscription plans from low tens | Requires a separate Data Display and Licensing Agreement | Subscription alone doesn't cover an app |
| JBlanked, Forex Factory scrapes | Free | Not licensed | Aggregated from MQL5 and Forex Factory. Out, per the brief |

What FXMacroData costs at scale, using their published formula:

| Measured users | Monthly |
|---|---|
| 250 | $25 |
| 1,000 | $100 |
| 5,000 | $500 |
| 20,000 | $2,000 |

Trading Economics at $149 to $299 a month is cheaper than FXMacroData from roughly
2,000 users upward, if their redistribution quote stays near list price. Below that,
FXMacroData is cheaper and needs no negotiation.

Recommendation. Ask both for a written quote that names an app with anonymous end
users and push notifications derived from the feed. Run both feeds side by side for
two weeks against FTMO's restricted-event list and a hand-checked set of twenty
releases, scoring event coverage, timestamp accuracy to the minute, revision
latency, and impact-rating agreement. Sign the one that scores higher unless the
price gap is more than double.

Ceiling: if neither comes in under $500 a month at 5,000 users, the free tier's
economics need revisiting before build, not after.
