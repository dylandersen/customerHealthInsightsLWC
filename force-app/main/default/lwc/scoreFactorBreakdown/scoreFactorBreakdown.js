import { LightningElement, api } from "lwc";

export default class ScoreFactorBreakdown extends LightningElement {
  @api factors = [];
  @api compositeScore = 0;

  get hasData() {
    return this.factors && this.factors.length > 0;
  }

  get compositeGrade() {
    const s = this.compositeScore || 0;
    if (s >= 80) return "Excellent";
    if (s >= 60) return "Good";
    if (s >= 40) return "Fair";
    if (s >= 20) return "At Risk";
    return "Critical";
  }

  get compositeScoreClass() {
    return "composite-score composite-score-" + this.compositeGrade.toLowerCase().replace(" ", "-");
  }

  get compositeGradeClass() {
    return "factor-grade " + this.gradeClassFor(this.compositeGrade);
  }

  get processedFactors() {
    if (!this.factors) return [];
    return this.factors.map((f, i) => ({
      key: `factor-${i}`,
      name: f.name,
      score: f.score,
      weight: f.weight,
      insight: f.insight,
      grade: f.grade,
      barStyle: `width: ${Math.max(f.score, 2)}%`,
      barClass: `factor-bar ${this.barClassFor(f.score)}`,
      gradeClass: `factor-grade ${this.gradeClassFor(f.grade)}`,
      iconName: this.iconFor(f.name)
    }));
  }

  barClassFor(score) {
    if (score >= 80) return "bar-excellent";
    if (score >= 60) return "bar-good";
    if (score >= 40) return "bar-fair";
    return "bar-risk";
  }

  gradeClassFor(grade) {
    if (grade === "Excellent") return "grade-excellent";
    if (grade === "Good") return "grade-good";
    if (grade === "Fair") return "grade-fair";
    if (grade === "At Risk") return "grade-at-risk";
    return "grade-critical";
  }

  iconFor(name) {
    if (name.includes("Support")) return "utility:shield";
    if (name.includes("Engagement")) return "utility:date_time";
    if (name.includes("Financial")) return "utility:chart";
    if (name.includes("Adoption")) return "utility:target";
    if (name.includes("Relationship")) return "utility:groups";
    return "utility:rows";
  }
}
