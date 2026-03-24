import { LightningElement, api } from "lwc";

const MONTHS_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

const W = 600, H = 300;
const PL = 50, PR = 20, PT = 20, PB = 30;
const PW = W - PL - PR;
const PH = H - PT - PB;

export default class ScoreHistoryTrend extends LightningElement {
  @api historyData = [];
  @api currentScore;

  showTooltip = false;
  _tooltipScore = "";
  _tooltipLabel = "";
  tooltipStyle = "";

  get hasData() {
    return this.historyData && this.historyData.length > 0;
  }

  get viewBox() { return `0 0 ${W} ${H}`; }

  get greenZoneY() { return PT; }
  get greenZoneH() { return (20 / 100) * PH; }
  get yellowZoneY() { return PT + (20 / 100) * PH; }
  get yellowZoneH() { return (40 / 100) * PH; }
  get redZoneY() { return PT + (60 / 100) * PH; }
  get redZoneH() { return (40 / 100) * PH; }
  get zoneX() { return PL; }
  get zoneW() { return PW; }

  get gridLines() {
    const lines = [];
    for (let v = 0; v <= 100; v += 25) {
      const y = PT + ((100 - v) / 100) * PH;
      lines.push({ key: `g-${v}`, x1: PL, y1: y, x2: PL + PW, y2: y, label: String(v), lx: PL - 8, ly: y + 4 });
    }
    return lines;
  }

  get dataPoints() {
    if (!this.historyData || this.historyData.length === 0) return [];
    const n = this.historyData.length;
    const step = n > 1 ? PW / (n - 1) : 0;
    const labelStep = Math.max(1, Math.floor(n / 6));

    return this.historyData.map((pt, i) => {
      const x = PL + i * step;
      const y = PT + ((100 - pt.score) / 100) * PH;
      const d = new Date(pt.dataDate + "T00:00:00");
      const label = `${MONTHS_SHORT[d.getMonth()]} '${String(d.getFullYear()).slice(2)}`;
      const show = i % labelStep === 0 || i === n - 1;
      return {
        key: `p-${i}`, cx: x, cy: y, score: pt.score,
        label: show ? label : "", lx: x, ly: H - 8,
        color: this.colorFor(pt.score),
        tooltipLabel: label,
        tooltipScore: `${pt.score}/100`
      };
    });
  }

  get linePath() {
    const pts = this.dataPoints;
    if (!pts.length) return "";
    return pts.map((p, i) => `${i === 0 ? "M" : "L"} ${p.cx} ${p.cy}`).join(" ");
  }

  get areaPath() {
    const pts = this.dataPoints;
    if (!pts.length) return "";
    const bottom = PT + PH;
    let path = `M ${pts[0].cx} ${bottom}`;
    for (const p of pts) path += ` L ${p.cx} ${p.cy}`;
    path += ` L ${pts[pts.length - 1].cx} ${bottom} Z`;
    return path;
  }

  colorFor(score) {
    if (score >= 80) return "#2e844a";
    if (score >= 60) return "#4bca81";
    if (score >= 40) return "#ffb75d";
    if (score >= 20) return "#fe9339";
    return "#c23934";
  }

  get lineColor() { return this.colorFor(this.currentScore || 50); }

  get zoneLabelX() { return PL + PW - 5; }
  get excellentLabelY() { return PT + this.greenZoneH / 2 + 3; }
  get fairLabelY() { return PT + (20 / 100) * PH + this.yellowZoneH / 2 + 3; }
  get riskLabelY() { return PT + (60 / 100) * PH + this.redZoneH / 2 + 3; }

  handleDotHover(event) {
    const el = event.currentTarget;
    const container = this.template.querySelector(".chart-container");
    if (!container) return;
    const cRect = container.getBoundingClientRect();
    const eRect = el.getBoundingClientRect();
    const x = eRect.left + eRect.width / 2 - cRect.left;
    const y = eRect.top - cRect.top;
    const idx = el.dataset.index;
    const pt = this.dataPoints.find((p) => p.key === idx);
    if (!pt) return;
    this._tooltipScore = pt.tooltipScore;
    this._tooltipLabel = pt.tooltipLabel;
    this.tooltipStyle = `left: ${x}px; top: ${y}px;`;
    this.showTooltip = true;
  }

  handleDotLeave() {
    this.showTooltip = false;
  }
}
