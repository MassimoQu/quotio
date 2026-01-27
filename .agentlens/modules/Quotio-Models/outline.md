# Outline

[← Back to MODULE](MODULE.md) | [← Back to INDEX](../../INDEX.md)

Symbol maps for 3 large files in this module.

## Quotio/Models/MenuBarSettings.swift (572 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 13 | mod | extension String | (internal) |
| 17 | fn | masked | (internal) |
| 38 | fn | masked | (internal) |
| 46 | struct | MenuBarQuotaItem | (internal) |
| 70 | enum | AppearanceMode | (internal) |
| 97 | class | AppearanceManager | (internal) |
| 112 | method | init | (private) |
| 119 | fn | applyAppearance | (internal) |
| 134 | enum | MenuBarColorMode | (internal) |
| 151 | enum | QuotaDisplayMode | (internal) |
| 165 | fn | displayValue | (internal) |
| 183 | enum | QuotaDisplayStyle | (internal) |
| 210 | enum | RefreshCadence | (internal) |
| 253 | enum | TotalUsageMode | (internal) |
| 270 | enum | ModelAggregationMode | (internal) |
| 286 | mod | extension MenuBarSettingsManager | (internal) |
| 334 | fn | calculateTotalUsagePercent | (internal) |
| 359 | fn | aggregateModelPercentages | (internal) |
| 376 | class | RefreshSettingsManager | (internal) |
| 394 | method | init | (private) |
| 404 | struct | MenuBarQuotaDisplayItem | (internal) |
| 421 | class | MenuBarSettingsManager | (internal) |
| 489 | method | init | (private) |
| 511 | fn | saveSelectedItems | (private) |
| 517 | fn | loadSelectedItems | (private) |
| 525 | fn | addItem | (internal) |
| 538 | fn | removeItem | (internal) |
| 543 | fn | isSelected | (internal) |
| 548 | fn | toggleItem | (internal) |
| 557 | fn | pruneInvalidItems | (internal) |
| 561 | fn | autoSelectNewAccounts | (internal) |

## Quotio/Models/Models.swift (602 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 302 | fn | hash | (internal) |
| 489 | method | init | (internal) |
| 506 | mod | extension Int | (internal) |
| 552 | fn | validate | (internal) |
| 592 | fn | sanitize | (internal) |

## Quotio/Models/SmartRoutingModels.swift (527 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 26 | enum | RefreshFrequencyLevel | (internal) |
| 87 | fn | detect | (internal) |
| 138 | enum | RoutingStrategy | (internal) |
| 178 | struct | SmartRoutingEntry | (internal) |
| 218 | method | init | (internal) |
| 284 | fn | recordSuccess | (internal) |
| 294 | fn | recordFailure | (internal) |
| 303 | fn | enterCooldown | (internal) |
| 311 | fn | exitCooldown | (internal) |
| 322 | struct | SmartVirtualModel | (internal) |
| 354 | method | init | (internal) |
| 369 | fn | selectNextEntry | (internal) |
| 390 | fn | selectRoundRobin | (private) |
| 396 | fn | selectFillFirst | (private) |
| 402 | fn | selectSmartPriority | (private) |
| 409 | fn | selectLoadBalanced | (private) |
| 419 | fn | selectCacheFirst | (private) |
| 454 | struct | SmartRoutingStats | (internal) |
| 461 | method | init | (internal) |
| 497 | struct | SmartRoutingConfiguration | (internal) |
| 503 | method | init | (internal) |
| 519 | fn | findVirtualModel | (internal) |

