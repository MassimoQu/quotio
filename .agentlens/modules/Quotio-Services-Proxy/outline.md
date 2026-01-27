# Outline

[← Back to MODULE](MODULE.md) | [← Back to INDEX](../../INDEX.md)

Symbol maps for 3 large files in this module.

## Quotio/Services/Proxy/CLIProxyManager.swift (1860 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 9 | class | CLIProxyManager | (internal) |
| 181 | method | init | (internal) |
| 214 | fn | updateConfigValue | (private) |
| 234 | fn | updateConfigPort | (private) |
| 238 | fn | updateConfigHost | (private) |
| 242 | fn | ensureApiKeyExistsInConfig | (private) |
| 291 | fn | updateConfigLogging | (internal) |
| 298 | fn | updateConfigRoutingStrategy | (internal) |
| 302 | fn | updateConfigProxyURL | (internal) |
| 322 | fn | ensureConfigExists | (private) |
| 356 | fn | syncSecretKeyInConfig | (private) |
| 372 | fn | regenerateManagementKey | (internal) |
| 403 | fn | syncProxyURLInConfig | (private) |
| 416 | fn | syncCustomProvidersToConfig | (private) |
| 433 | fn | downloadAndInstallBinary | (internal) |
| 494 | fn | fetchLatestRelease | (private) |
| 515 | fn | findCompatibleAsset | (private) |
| 540 | fn | downloadAsset | (private) |
| 559 | fn | extractAndInstall | (private) |
| 621 | fn | findBinaryInDirectory | (private) |
| 654 | fn | start | (internal) |
| 786 | fn | stop | (internal) |
| 842 | fn | startHealthMonitor | (private) |
| 856 | fn | stopHealthMonitor | (private) |
| 861 | fn | performHealthCheck | (private) |
| 924 | fn | cleanupOrphanProcesses | (private) |
| 978 | fn | terminateAuthProcess | (internal) |
| 984 | fn | toggle | (internal) |
| 992 | fn | copyEndpointToClipboard | (internal) |
| 997 | fn | revealInFinder | (internal) |
| 1003 | enum | ProxyError | (internal) |
| 1034 | enum | AuthCommand | (internal) |
| 1072 | struct | AuthCommandResult | (internal) |
| 1078 | mod | extension CLIProxyManager | (internal) |
| 1079 | fn | runAuthCommand | (internal) |
| 1111 | fn | appendOutput | (internal) |
| 1115 | fn | tryResume | (internal) |
| 1126 | fn | safeResume | (internal) |
| 1226 | mod | extension CLIProxyManager | (internal) |
| 1255 | fn | checkForUpgrade | (internal) |
| 1336 | fn | saveInstalledVersion | (private) |
| 1344 | fn | fetchAvailableReleases | (internal) |
| 1366 | fn | versionInfo | (internal) |
| 1372 | fn | fetchGitHubRelease | (private) |
| 1394 | fn | findCompatibleAsset | (private) |
| 1427 | fn | performManagedUpgrade | (internal) |
| 1481 | fn | downloadAndInstallVersion | (private) |
| 1528 | fn | startDryRun | (private) |
| 1599 | fn | promote | (private) |
| 1634 | fn | rollback | (internal) |
| 1667 | fn | stopTestProxy | (private) |
| 1696 | fn | stopTestProxySync | (private) |
| 1722 | fn | findUnusedPort | (private) |
| 1732 | fn | isPortInUse | (private) |
| 1751 | fn | createTestConfig | (private) |
| 1779 | fn | cleanupTestConfig | (private) |
| 1787 | fn | isNewerVersion | (private) |
| 1790 | fn | parseVersion | (internal) |
| 1822 | fn | findPreviousVersion | (private) |
| 1835 | fn | migrateToVersionedStorage | (internal) |

## Quotio/Services/Proxy/ModelUsageTracker.swift (746 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 33 | enum | UsageTimePeriod | (internal) |
| 87 | struct | UsageDataPoint | (internal) |
| 99 | fn | formatLabel | (internal) |
| 121 | enum | UsageMetricType | (internal) |
| 182 | struct | ModelUsageData | (internal) |
| 236 | fn | chartData | (internal) |
| 274 | struct | ChartDataResult | (internal) |
| 280 | method | init | (internal) |
| 291 | struct | ChartSummary | (internal) |
| 298 | method | init | (internal) |
| 323 | class | ModelUsageTracker | (internal) |
| 352 | method | init | (private) |
| 367 | fn | recordRequest | (internal) |
| 432 | fn | createHistoryPoint | (private) |
| 450 | fn | usageData | (internal) |
| 455 | fn | chartData | (internal) |
| 484 | fn | sortedUsageData | (internal) |
| 491 | fn | usageByProvider | (internal) |
| 518 | fn | topModels | (internal) |
| 543 | fn | aggregateChartData | (internal) |
| 577 | fn | overallStats | (internal) |
| 597 | fn | usageTrends | (internal) |
| 628 | fn | saveToStorage | (internal) |
| 634 | fn | loadFromStorage | (internal) |
| 648 | fn | clearAllData | (internal) |
| 657 | fn | clearData | (internal) |
| 674 | fn | formatLabel | (private) |
| 696 | struct | ProviderUsageSummary | (internal) |
| 710 | struct | OverallUsageStats | (internal) |
| 721 | struct | UsageTrends | (internal) |

## Quotio/Services/Proxy/ProxyBridge.swift (1431 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 38 | struct | FallbackContext | (internal) |
| 82 | struct | SmartRoutingContext | (internal) |
| 107 | class | ProxyBridge | (internal) |
| 173 | method | init | (internal) |
| 182 | fn | configure | (internal) |
| 205 | fn | start | (internal) |
| 248 | fn | stop | (internal) |
| 261 | fn | handleListenerState | (private) |
| 277 | fn | handleNewConnection | (private) |

