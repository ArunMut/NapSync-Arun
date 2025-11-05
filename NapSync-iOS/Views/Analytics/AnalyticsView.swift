import SwiftUI
import Charts

struct AnalyticsView: View {
    private let weeklyNapData: [DailyNapMetric] = [
        .init(day: "Mon", duration: 82, efficiency: 0.87, readiness: 68),
        .init(day: "Tue", duration: 74, efficiency: 0.83, readiness: 71),
        .init(day: "Wed", duration: 68, efficiency: 0.79, readiness: 75),
        .init(day: "Thu", duration: 90, efficiency: 0.9, readiness: 84),
        .init(day: "Fri", duration: 76, efficiency: 0.85, readiness: 80),
        .init(day: "Sat", duration: 63, efficiency: 0.74, readiness: 62),
        .init(day: "Sun", duration: 70, efficiency: 0.8, readiness: 66)
    ]

    private let napQualityStats: [MetricSummary] = [
        .init(title: "Recovery Score", value: "82", subtitle: "↑6 vs last week", color: .green),
        .init(title: "Avg Duration", value: "76 min", subtitle: "Target window hit", color: .blue),
        .init(title: "Wake Refresh", value: "92%", subtitle: "Optimal cycle exit", color: .orange),
        .init(title: "Readiness", value: "78", subtitle: "Well primed", color: .purple)
    ]

    private let sleepStageBreakdown: [SleepStageDistribution] = [
        .init(stage: "Light", percentage: 42),
        .init(stage: "Deep", percentage: 31),
        .init(stage: "REM", percentage: 19),
        .init(stage: "Wake", percentage: 8)
    ]

    private let biometricsTrend: [BiometricTrend] = [
        .init(minute: 0, heartRate: 74, hrv: 48, respiratoryRate: 16.5),
        .init(minute: 15, heartRate: 69, hrv: 54, respiratoryRate: 15.2),
        .init(minute: 30, heartRate: 65, hrv: 58, respiratoryRate: 14.8),
        .init(minute: 45, heartRate: 63, hrv: 61, respiratoryRate: 14.1),
        .init(minute: 60, heartRate: 60, hrv: 65, respiratoryRate: 13.9),
        .init(minute: 75, heartRate: 62, hrv: 62, respiratoryRate: 14.3)
    ]

    private let sleepDebt: SleepDebtSnapshot = .init(
        weeklyDelta: -42,
        longestStreak: 4,
        idealBedtime: "1:40 PM",
        napPayoff: "3h 15m repaid this week"
    )

    private let recommendations: [AnalyticsRecommendation] = [
        .init(title: "Ideal Nap Window", detail: "Most restorative naps start between 1:30–2:15 PM. Consider scheduling reminders 20 minutes ahead."),
        .init(title: "Recovery Sweet Spot", detail: "Wake near the 75 minute mark to hit peak HRV rebound. Our ML model predicts 93% refreshed wake-ups there."),
        .init(title: "Smart Prep", detail: "Light cardio 90 minutes prior correlated with a 12% efficiency boost this week."),
        .init(title: "Ambient Cues", detail: "Room temp at 68–70°F mapped to your calmest wake transitions. Keep the blinds 30% open for natural light cues."),
        .init(title: "Wind Down", detail: "Box breathing for 3 minutes before resting lowered heart rate onset by 7 BPM on average.")
    ]

    private let timelineEvents: [NapTimelineEvent] = [
        .init(label: "Settled", minute: 0, detail: "Heart rate 74 BPM", icon: "bed.double.fill"),
        .init(label: "Drift", minute: 18, detail: "HRV stabilised", icon: "waveform"),
        .init(label: "Deep", minute: 36, detail: "Core temp dip", icon: "snowflake"),
        .init(label: "REM", minute: 58, detail: "Resp 13.9/min", icon: "eye"),
        .init(label: "Wake Cue", minute: 74, detail: "Light vibration triggered", icon: "alarm.fill")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                metricHighlights
                weeklyPerformance
                cycleTimeline
                biometricsSection
                sleepStageSection
                sleepDebtSection
                recommendationSection
            }
            .padding(.horizontal)
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Analytics")
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This Week's Performance")
                .font(.title2)
                .fontWeight(.semibold)

            Text("AI generated insights from 6 tracked naps. Updated 2h ago based on your latest HealthKit trends.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var metricHighlights: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(napQualityStats) { metric in
                    VStack(alignment: .leading, spacing: 12) {
                        Label(metric.title, systemImage: metric.iconName)
                            .font(.caption)
                            .foregroundColor(metric.color)

                        Text(metric.value)
                            .font(.system(size: 32, weight: .bold))

                        Text(metric.subtitle)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(width: 190, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(metric.color.opacity(0.12))
                    )
                }
            }
        }
    }

    private var weeklyPerformance: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Weekly Recovery Curve", subtitle: "Duration vs efficiency across your last 7 naps")

            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(weeklyNapData) { dataPoint in
                        BarMark(
                            x: .value("Day", dataPoint.day),
                            y: .value("Duration", dataPoint.duration)
                        )
                        .foregroundStyle(Color.accentColor.opacity(0.65))
                        .cornerRadius(8)

                        LineMark(
                            x: .value("Day", dataPoint.day),
                            y: .value("Efficiency", dataPoint.efficiency * 100)
                        )
                        .foregroundStyle(.purple)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Day", dataPoint.day),
                            y: .value("Efficiency", dataPoint.efficiency * 100)
                        )
                        .symbolSize(60)
                        .foregroundStyle(.purple)

                        AreaMark(
                            x: .value("Day", dataPoint.day),
                            y: .value("Readiness", dataPoint.readiness)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Gradient(colors: [.purple.opacity(0.25), .clear]))
                    }
                }
                .frame(height: 240)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartYAxisLabel("Minutes / %", position: .leading)
                .chartLegend(.hidden)
            } else {
                legacyGraph
            }

            Divider()

            HStack(spacing: 16) {
                InsightPill(title: "Best Nap", detail: "Thu • 90 min • 90% efficient", systemImage: "arrow.up.right")
                InsightPill(title: "Needs Attention", detail: "Sat • 63 min • disrupted", systemImage: "exclamationmark.triangle")
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
    }

    private var cycleTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Last Nap Timeline", subtitle: "Minute-by-minute breakdown from the latest tracked nap")

            ForEach(timelineEvents) { event in
                HStack(alignment: .top, spacing: 14) {
                    TimelineBadge(icon: event.icon)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.label)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(event.minute)m")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(event.detail)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 6)
                .overlay(
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.08))
                        .frame(height: 1)
                        .offset(y: 22)
                        .opacity(event != timelineEvents.last ? 1 : 0)
                    , alignment: .bottom
                )
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
    }

    private var biometricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Biometric Trends", subtitle: "Heart rate & HRV progression during your optimal nap window")

            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(biometricsTrend) { point in
                        LineMark(
                            x: .value("Minutes", point.minute),
                            y: .value("Heart Rate", point.heartRate)
                        )
                        .foregroundStyle(.red)
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Minutes", point.minute),
                            y: .value("HRV", point.hrv)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Minutes", point.minute),
                            y: .value("Respiratory", point.respiratoryRate)
                        )
                        .foregroundStyle(.mint.opacity(0.25))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 240)
                .chartYAxisLabel("BPM / ms / RPM", position: .leading)
            } else {
                legacyGraph
            }

            VStack(alignment: .leading, spacing: 8) {
                InsightPill(title: "Cycle Trigger", detail: "HRV peaks at 60 min signalling ideal wake window", systemImage: "bell")
                InsightPill(title: "Calm Onset", detail: "Heart rate drops 14 BPM within the first 20 minutes", systemImage: "heart")
                InsightPill(title: "Steady Breathing", detail: "Respiration holds at 14/min while you transition to REM", systemImage: "lungs.fill")
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
    }

    private var sleepStageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Sleep Stage Composition", subtitle: "Average distribution across last 5 naps")

            HStack(alignment: .bottom, spacing: 16) {
                ForEach(sleepStageBreakdown) { stage in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(stage.color)
                            .frame(width: 50, height: CGFloat(stage.percentage) * 2)
                            .overlay(
                                Text("\(stage.percentage)%")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(4),
                                alignment: .top
                            )

                        Text(stage.stage)
                            .font(.footnote)
                            .fontWeight(.medium)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            Text("Deep sleep increased 9% this week after consistent wind-down breathing routines.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
    }

    private var sleepDebtSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Recovery Outlook", subtitle: "How your naps are helping repay sleep debt")

            HStack(spacing: 16) {
                Gauge(value: Double(max(0, 100 + sleepDebt.weeklyDelta)), in: 0...100) {
                    Text("Debt")
                } currentValueLabel: {
                    Text("\(sleepDebt.weeklyDelta) min")
                        .font(.caption)
                }
                .tint(.purple)
                .gaugeStyle(.accessoryCircular)
                .frame(width: 90, height: 90)

                VStack(alignment: .leading, spacing: 8) {
                    Text(sleepDebt.napPayoff)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Longest streak: \(sleepDebt.longestStreak) optimal naps in a row")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("Ideal start time this week: \(sleepDebt.idealBedtime)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Actionable Insights", subtitle: "Adjustments based on your AI nap coach")

            ForEach(recommendations) { recommendation in
                VStack(alignment: .leading, spacing: 6) {
                    Text(recommendation.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(recommendation.detail)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var legacyGraph: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.accentColor.opacity(0.6))
                    .frame(width: 60, height: 12)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.purple.opacity(0.6))
                    .frame(width: 120, height: 12)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.mint.opacity(0.4))
                    .frame(width: 40, height: 12)
            }

            Text("Charts require iOS 16+. Upgrade to view detailed graphs.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Supporting Models

private struct DailyNapMetric: Identifiable {
    let id = UUID()
    let day: String
    let duration: Double
    let efficiency: Double
    let readiness: Double
}

private struct SleepStageDistribution: Identifiable {
    let id = UUID()
    let stage: String
    let percentage: Int

    var color: Color {
        switch stage {
        case "Deep": return .indigo
        case "REM": return .mint
        case "Light": return .teal
        case "Wake": return .gray
        default: return .blue
        }
    }
}

private struct BiometricTrend: Identifiable {
    let id = UUID()
    let minute: Int
    let heartRate: Double
    let hrv: Double
    let respiratoryRate: Double
}

private struct AnalyticsRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

private struct MetricSummary: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var iconName: String {
        switch title {
        case "Recovery Score": return "bolt.heart"
        case "Avg Duration": return "stopwatch.fill"
        case "Wake Refresh": return "sun.max.fill"
        case "Readiness": return "brain.head.profile"
        default: return "sparkles"
        }
    }
}

private struct InsightPill: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(10)
        .background(
            Capsule()
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
}

private struct SleepDebtSnapshot {
    let weeklyDelta: Int
    let longestStreak: Int
    let idealBedtime: String
    let napPayoff: String
}

private struct NapTimelineEvent: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let minute: Int
    let detail: String
    let icon: String
}

private struct TimelineBadge: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.footnote)
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
    }
}

#Preview {
    NavigationView {
        AnalyticsView()
    }
}
