package load

import (
	"sort"
	"time"
)

type LoadTestMetrics struct {
	Duration       time.Duration
	QueriesTotal   int
	QueriesSuccess int
	QueriesFailed  int
	AvgLatency     time.Duration
	P50Latency     time.Duration
	P95Latency     time.Duration
	P99Latency     time.Duration
	ThroughputQPS  float64
}

func calculateLatencyMetrics(latencies []time.Duration) *LoadTestMetrics {
	if len(latencies) == 0 {
		return &LoadTestMetrics{}
	}
	sorted := make([]time.Duration, len(latencies))
	copy(sorted, latencies)
	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i] < sorted[j]
	})
	var sum time.Duration
	for _, l := range sorted {
		sum += l
	}
	avgLatency := sum / time.Duration(len(sorted))
	p50 := sorted[len(sorted)*50/100]
	p95 := sorted[len(sorted)*95/100]
	p99 := sorted[len(sorted)*99/100]
	return &LoadTestMetrics{
		AvgLatency: avgLatency,
		P50Latency: p50,
		P95Latency: p95,
		P99Latency: p99,
	}
}
