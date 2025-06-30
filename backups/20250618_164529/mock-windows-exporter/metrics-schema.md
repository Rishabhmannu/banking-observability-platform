# COUNTER METRICS (cumulative values that only increase)
windows_iis_requests_total{method="GET|POST|PUT|DELETE", site="Default Web Site|BankingApp|API Portal"}
- Example: windows_iis_requests_total{method="GET",site="BankingApp"} 45678.0
- Example: windows_iis_requests_total{method="POST",site="API Portal"} 12345.0

windows_iis_not_found_errors_total{site="Default Web Site|BankingApp|API Portal"}
- Example: windows_iis_not_found_errors_total{site="BankingApp"} 234.0

windows_iis_server_errors_total{site="Default Web Site|BankingApp|API Portal"}
- Example: windows_iis_server_errors_total{site="Default Web Site"} 56.0

windows_iis_client_errors_total{site="Default Web Site|BankingApp|API Portal"}
- Example: windows_iis_client_errors_total{site="API Portal"} 123.0

windows_netframework_exceptions_thrown_total{app_name="*_App", exception_type="System.*"}
- Example: windows_netframework_exceptions_thrown_total{app_name="BankingApp_App",exception_type="System.NullReferenceException"} 89.0

windows_custom_errors_total{error_code="ERR_*", app_name="*_App"}
- Example: windows_custom_errors_total{error_code="ERR_AUTH_002",app_name="BankingApp_App"} 45.0

# GAUGE METRICS (values that can go up or down)
windows_iis_current_connections{site="Default Web Site|BankingApp|API Portal"}
- Example: windows_iis_current_connections{site="BankingApp"} 234.0

windows_iis_app_pool_state{app_pool="DefaultAppPool|BankingAppPool|APIPool"}
- Example: windows_iis_app_pool_state{app_pool="BankingAppPool"} 1.0 (1=running, 0=stopped)

windows_iis_worker_processes{app_pool="*Pool", state="running|idle"}
- Example: windows_iis_worker_processes{app_pool="BankingAppPool",state="running"} 4.0

# HISTOGRAM METRICS (track distributions of values)
windows_iis_request_wait_time{site="*", le="5|10|25|50|100|250|500|1000|2500|5000|10000|+Inf"}
- Example: windows_iis_request_wait_time_bucket{site="BankingApp",le="50"} 12345.0
- Example: windows_iis_request_wait_time_sum{site="BankingApp"} 567890.0
- Example: windows_iis_request_wait_time_count{site="BankingApp"} 23456.0

windows_iis_request_execution_time{site="*", le="5|10|25|50|100|250|500|1000|2500|5000|10000|+Inf"}
- Example: windows_iis_request_execution_time_bucket{site="API Portal",le="100"} 34567.0


Data Generation Pattern
The synthetic data follows these patterns:

Base Load: 100 requests/second distributed across 3 sites
Time-based Variation:

Business hours (9-17): 2x-2.5x multiplier
Night hours: 0.3x multiplier


Error Rates:

Normal: 0.1% 5xx, 0.4% 404, 0.5% other 4xx
High Error Mode: 5% 5xx, 3% 404, 2% other 4xx


Response Times:

Normal: Gaussian distribution (mean=50ms, std=20ms)
Degraded: 3-5x multiplier


Exception Rate: 0.2% of requests generate .NET exceptions
Custom Errors: 0.3% of requests generate custom error codes



# Volume Surge Detection
(current_rate / 30min_average) > 2 = SURGE
(current_rate / 30min_average) < 0.5 = DIP

# Success Rate
((total_requests - server_errors - client_errors) / total_requests) * 100

# Technical Exception Percentage
(exceptions_thrown / total_requests) * 100

# Response Time Degradation
P95(execution_time) > 500ms = DEGRADATION