import { LightningElement, api, track } from "lwc";
import generateHealthSummary from "@salesforce/apex/CustomerHealthScoreController.generateHealthSummary";
import AGENTFORCE_ICON from "@salesforce/resourceUrl/AgentforceRGBIcon";

const AI_CACHE_PREFIX = "healthAI_";

const LOADING_MESSAGES = [
  "Analyzing account health signals...",
  "Reviewing recent cases and emails...",
  "Evaluating engagement patterns...",
  "Assessing pipeline and financial health...",
  "Generating recommendations..."
];

export default class HealthActionAlerts extends LightningElement {
  @api alerts = [];
  @api metrics = {};
  @api engagements = [];
  @api topics = [];

  _accountId;
  @api
  get accountId() { return this._accountId; }
  set accountId(value) {
    this._accountId = value;
    this.restoreCachedInsights();
  }

  @track insightsSummary = "";
  @track isGenerating = false;
  @track currentLoadingMessage = "";
  @track aiError = "";

  agentforceIcon = AGENTFORCE_ICON;
  _loadingInterval = null;
  _loadingMsgIndex = 0;

  disconnectedCallback() {
    this.stopLoadingMessages();
  }

  // ── Engagement / Topics ─────────────────────────────────

  get processedEngagements() {
    if (!this.engagements) return [];
    return [...this.engagements]
      .sort((a, b) => (b.totalCount || 0) - (a.totalCount || 0))
      .map((row, i) => this.processRow(row, i, "eng"));
  }

  get processedTopics() {
    if (!this.topics) return [];
    return [...this.topics]
      .sort((a, b) => (b.totalCount || 0) - (a.totalCount || 0))
      .map((row, i) => this.processRow(row, i, "topic"));
  }

  processRow(row, i, prefix) {
    const t = row.totalCount || 1;
    return {
      key: `${prefix}-${i}`,
      label: row.label,
      totalCount: row.totalCount,
      hasPositive: row.positive > 0,
      hasProfessional: row.professional > 0,
      hasMixed: row.mixed > 0,
      hasNegative: row.negative > 0,
      hasNotAnalyzed: (row.notAnalyzed || 0) > 0,
      posStyle: `width: ${Math.round((row.positive / t) * 100)}%`,
      proStyle: `width: ${Math.round((row.professional / t) * 100)}%`,
      mixStyle: `width: ${Math.round((row.mixed / t) * 100)}%`,
      negStyle: `width: ${Math.round((row.negative / t) * 100)}%`,
      naStyle: `width: ${Math.round(((row.notAnalyzed || 0) / t) * 100)}%`
    };
  }

  // ── Alerts ──────────────────────────────────────────────

  get hasAlerts() {
    return this.alerts && this.alerts.length > 0;
  }

  get processedAlerts() {
    if (!this.alerts) return [];
    return this.alerts.map((a, i) => ({
      key: `alert-${i}`,
      title: a.title,
      description: a.description,
      category: a.category,
      iconName: this.iconFor(a.severity),
      alertClass: `alert-card alert-${a.severity}`,
      iconClass: `alert-icon icon-${a.severity}`
    }));
  }

  iconFor(severity) {
    if (severity === "critical") return "utility:error";
    if (severity === "warning") return "utility:warning";
    return "utility:success";
  }

  // ── AI Health Insights ──────────────────────────────────

  get isGeneratingWithoutResult() {
    return this.isGenerating && !this.insightsSummary;
  }

  get isRegenerating() {
    return this.isGenerating && Boolean(this.insightsSummary);
  }

  get showAiEmptyState() {
    return !this.isGenerating && !this.insightsSummary;
  }

  get hasInsights() {
    return Boolean(this.insightsSummary) && !this.isGeneratingWithoutResult;
  }

  get parsedSections() {
    if (!this.insightsSummary) return [];
    const lines = this.insightsSummary.split("\n");
    const sections = [];
    let current = null;
    let sIdx = 0;
    let bIdx = 0;

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed) continue;

      // Numbered section headers like "1. Customer Relationship Health"
      if (/^\d+\.\s+[A-Z]/.test(trimmed)) {
        current = {
          key: `s-${sIdx++}`,
          heading: trimmed.replace(/^\d+\.\s+/, ""),
          paragraph: "",
          hasParagraph: false,
          bullets: []
        };
        sections.push(current);
      } else if (/^[-]/.test(trimmed)) {
        // Bullet line
        if (!current) {
          current = { key: `s-${sIdx++}`, heading: "Analysis", paragraph: "", hasParagraph: false, bullets: [] };
          sections.push(current);
        }
        current.bullets.push({ key: `b-${bIdx++}`, text: trimmed.replace(/^[-]\s*/, "") });
      } else if (current && !current.hasParagraph && current.bullets.length === 0) {
        // Paragraph text right after a heading
        current.paragraph = trimmed;
        current.hasParagraph = true;
      } else if (current) {
        // Additional paragraph - append to existing or add as bullet
        if (current.hasParagraph) {
          current.paragraph += " " + trimmed;
        } else {
          current.bullets.push({ key: `b-${bIdx++}`, text: trimmed });
        }
      } else {
        // Text before any heading
        current = { key: `s-${sIdx++}`, heading: "Summary", paragraph: trimmed, hasParagraph: true, bullets: [] };
        sections.push(current);
      }
    }
    return sections;
  }

  get aiResultWrapperClass() {
    return "ai-result-wrapper" + (this.isRegenerating ? " ai-result-wrapper--revising" : "");
  }

  get aiResultContentClass() {
    return "ai-result-content" + (this.isRegenerating ? " ai-result-content--blurred" : "");
  }

  restoreCachedInsights() {
    if (!this._accountId) {
      this.insightsSummary = "";
      return;
    }
    try {
      const cached = sessionStorage.getItem(AI_CACHE_PREFIX + this._accountId);
      if (cached) {
        this.insightsSummary = cached;
      } else {
        this.insightsSummary = "";
      }
    } catch (_e) {
      this.insightsSummary = "";
    }
  }

  handleGenerate() {
    if (!this.accountId) return;
    this.isGenerating = true;
    this.aiError = "";
    if (!this.insightsSummary) {
      this.insightsSummary = "";
    }
    this.startLoadingMessages();

    generateHealthSummary({ accountId: this.accountId })
      .then((result) => {
        this.insightsSummary = result || "";
        try { sessionStorage.setItem(AI_CACHE_PREFIX + this.accountId, this.insightsSummary); } catch (_e) { /* */ }
      })
      .catch((error) => {
        this.aiError = error?.body?.message || error?.message || "Failed to generate summary.";
        if (!this.insightsSummary) {
          this.insightsSummary = "";
        }
      })
      .finally(() => {
        this.isGenerating = false;
        this.stopLoadingMessages();
      });
  }

  startLoadingMessages() {
    this._loadingMsgIndex = 0;
    this.currentLoadingMessage = LOADING_MESSAGES[0];
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._loadingInterval = setInterval(() => {
      this._loadingMsgIndex = (this._loadingMsgIndex + 1) % LOADING_MESSAGES.length;
      this.currentLoadingMessage = LOADING_MESSAGES[this._loadingMsgIndex];
    }, 2500);
  }

  stopLoadingMessages() {
    if (this._loadingInterval) {
      clearInterval(this._loadingInterval);
      this._loadingInterval = null;
    }
    this.currentLoadingMessage = "";
  }
}
