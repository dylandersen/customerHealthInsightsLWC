import { LightningElement, api } from "lwc";

export default class HealthScoreCard extends LightningElement {
  @api healthData;

  get hasData() {
    return this.healthData && this.healthData.compositeScore != null;
  }

  get gaugeDashArray() { return 2 * Math.PI * 76; }

  get gaugeDashOffset() {
    if (!this.healthData) return this.gaugeDashArray;
    const pct = Math.min(this.healthData.compositeScore || 0, 100) / 100;
    return this.gaugeDashArray * (1 - pct);
  }

  get scoreColor() {
    if (!this.healthData) return "#e5e5e5";
    const s = this.healthData.compositeScore || 0;
    if (s >= 80) return "#2e844a";
    if (s >= 60) return "#4bca81";
    if (s >= 40) return "#ffb75d";
    if (s >= 20) return "#fe9339";
    return "#c23934";
  }

  get gradeDisplay() { return this.healthData?.grade || "—"; }

  get gradeClass() {
    const g = this.healthData?.grade || "";
    if (g === "Excellent") return "grade-badge grade-excellent";
    if (g === "Good") return "grade-badge grade-good";
    if (g === "Fair") return "grade-badge grade-fair";
    if (g === "At Risk") return "grade-badge grade-at-risk";
    if (g === "Critical") return "grade-badge grade-critical";
    return "grade-badge";
  }

  get trendDisplay() { return this.healthData?.trend || "—"; }

  get trendIcon() {
    const t = this.healthData?.trend;
    if (t === "Improving") return "utility:arrowup";
    if (t === "Declining") return "utility:arrowdown";
    return "utility:forward";
  }

  get trendIconClass() {
    const t = this.healthData?.trend;
    if (t === "Improving") return "metric-icon trend-up-icon";
    if (t === "Declining") return "metric-icon trend-down-icon";
    return "metric-icon trend-stable-icon";
  }

  get trendValueClass() {
    const t = this.healthData?.trend;
    if (t === "Improving") return "metric-value trend-up";
    if (t === "Declining") return "metric-value trend-down";
    return "metric-value trend-stable";
  }

  // ── Churn Risk ─────────────────────────────────────────

  get churnRiskLevel() {
    const score = this.healthData?.compositeScore || 0;
    const factors = this.healthData?.factors || [];
    let criticalCount = 0;
    let warningCount = 0;
    for (const f of factors) {
      if (f.score < 35) criticalCount++;
      else if (f.score < 55) warningCount++;
    }
    const trend = this.healthData?.trend;
    const escalated = this.healthData?.metrics?.escalatedCases || 0;

    if (score < 40 || criticalCount >= 2 || (criticalCount >= 1 && trend === "Declining")) return "High";
    if (score < 65 || criticalCount >= 1 || warningCount >= 2 || escalated >= 2) return "Medium";
    return "Low";
  }

  get churnEmoji() {
    const r = this.churnRiskLevel;
    if (r === "High") return "\uD83D\uDD34";
    if (r === "Medium") return "\uD83D\uDFE1";
    return "\uD83D\uDFE2";
  }

  get churnCardClass() {
    const r = this.churnRiskLevel;
    if (r === "High") return "metric-card churn-card churn-high";
    if (r === "Medium") return "metric-card churn-card churn-medium";
    return "metric-card churn-card churn-low";
  }

  get churnValueClass() {
    const r = this.churnRiskLevel;
    if (r === "High") return "metric-value churn-value-high";
    if (r === "Medium") return "metric-value churn-value-medium";
    return "metric-value churn-value-low";
  }

  get churnRiskSub() {
    const r = this.churnRiskLevel;
    if (r === "High") return "Immediate action needed";
    if (r === "Medium") return "Monitor closely";
    return "Account is healthy";
  }

  get activitiesDisplay() { return this.healthData?.metrics?.totalActivities ?? "—"; }
  get activeOppsDisplay() { return this.healthData?.metrics?.activeOpps ?? "—"; }
  get contactsDisplay() { return this.healthData?.metrics?.contactCount ?? "—"; }

  get openCasesCount() { return this.healthData?.metrics?.openCases ?? 0; }
  get closedCasesCount() { return this.healthData?.metrics?.closedCases ?? 0; }
  get highPriorityCasesCount() { return this.healthData?.metrics?.highPriorityCases ?? 0; }

  get avgResolutionDisplay() {
    const val = this.healthData?.metrics?.avgResolutionDays;
    const closed = this.healthData?.metrics?.closedCases;
    if (val == null || !closed) return "—";
    if (val < 1) return "< 1d";
    return `${val}d`;
  }

  get pipelineDisplay() {
    const val = this.healthData?.metrics?.totalPipeline;
    if (val == null) return "—";
    const num = Number(val);
    if (num >= 1e6) return `$${(num / 1e6).toFixed(1)}M`;
    if (num >= 1e3) return `$${(num / 1e3).toFixed(1)}K`;
    return `$${num.toFixed(0)}`;
  }
}
