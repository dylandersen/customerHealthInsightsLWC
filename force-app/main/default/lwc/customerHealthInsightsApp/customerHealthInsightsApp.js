import { LightningElement, track, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import ACCOUNT_NAME_FIELD from "@salesforce/schema/Account.Name";
import getHealthScore from "@salesforce/apex/CustomerHealthScoreController.getHealthScore";
import AGENTFORCE_ICON from "@salesforce/resourceUrl/AgentforceRGBIcon";

const STORAGE_KEY = "customerHealthInsights_selectedAccountId";

const LOADING_MESSAGES = [
  "Analyzing customer health signals...",
  "Evaluating support ticket patterns...",
  "Measuring engagement frequency...",
  "Assessing financial trajectory...",
  "Analyzing product adoption depth...",
  "Mapping relationship breadth...",
  "Computing weighted factor scores...",
  "Calculating composite health score...",
  "Determining trend direction...",
  "Generating health insights...",
  "Evaluating risk indicators...",
  "Building factor breakdown...",
  "Analyzing stakeholder coverage...",
  "Computing executive engagement score...",
  "Finalizing health assessment..."
];

export default class CustomerHealthInsightsApp extends LightningElement {
  @track selectedAccountId = null;
  healthData = null;
  isLoading = false;
  hasError = false;
  errorMessage = "";
  currentLoadingMessage = "";
  agentforceIcon = AGENTFORCE_ICON;
  _loadingTimeout = null;
  _loadingMsgIndex = 0;

  @wire(getRecord, { recordId: "$selectedAccountId", fields: [ACCOUNT_NAME_FIELD] })
  _accountRecord;

  get accountName() {
    return getFieldValue(this._accountRecord?.data, ACCOUNT_NAME_FIELD) || "";
  }

  connectedCallback() {
    this.hideDefaultHeader();
    this.restorePersistedAccount();
  }

  disconnectedCallback() {
    this.stopLoadingMessages();
  }

  restorePersistedAccount() {
    try {
      const cached = sessionStorage.getItem(STORAGE_KEY);
      if (cached) {
        this.selectedAccountId = cached;
        this.fetchHealthData();
      }
    } catch (_e) {
      // sessionStorage unavailable
    }
  }

  hideDefaultHeader() {
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
      const fp = document.querySelector(".flexipageTemplate");
      if (!fp) return;
      fp.querySelectorAll(".slds-page-header, header.slds-page-header").forEach((h) => {
        if (!h.closest("c-customer-health-insights-app")) {
          const txt = h.textContent || "";
          if (txt.includes("Customer Health Insights") || h.querySelector(".slds-page-header__title")) {
            h.style.display = "none";
            h.style.visibility = "hidden";
            h.style.height = "0";
            h.style.overflow = "hidden";
          }
        }
      });
    }, 200);
  }

  handleAccountChange(event) {
    const accountId = event.detail.recordId;
    if (accountId) {
      this.selectedAccountId = accountId;
      try { sessionStorage.setItem(STORAGE_KEY, accountId); } catch (_e) { /* */ }
      this.fetchHealthData();
    } else {
      this.selectedAccountId = null;
      this.healthData = null;
      try { sessionStorage.removeItem(STORAGE_KEY); } catch (_e) { /* */ }
    }
  }

  fetchHealthData() {
    if (!this.selectedAccountId) return;
    this.isLoading = true;
    this.hasError = false;
    this.healthData = null;
    this.startLoadingMessages();

    getHealthScore({ accountId: this.selectedAccountId })
      .then((result) => {
        this.healthData = result;
      })
      .catch((error) => {
        this.hasError = true;
        this.errorMessage = error?.body?.message || error?.message || "Failed to load health score.";
      })
      .finally(() => {
        this.isLoading = false;
        this.stopLoadingMessages();
      });
  }

  handleRefresh() {
    this.fetchHealthData();
  }

  startLoadingMessages() {
    this._loadingMsgIndex = 0;
    this.currentLoadingMessage = LOADING_MESSAGES[0];
    this.scheduleNextMessage();
  }

  scheduleNextMessage() {
    const delay = 3000 + Math.random() * 2000;
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._loadingTimeout = setTimeout(() => {
      this._loadingMsgIndex = (this._loadingMsgIndex + 1) % LOADING_MESSAGES.length;
      this.currentLoadingMessage = LOADING_MESSAGES[this._loadingMsgIndex];
      this.scheduleNextMessage();
    }, delay);
  }

  stopLoadingMessages() {
    if (this._loadingTimeout) {
      clearTimeout(this._loadingTimeout);
      this._loadingTimeout = null;
    }
    this.currentLoadingMessage = "";
  }

  get hasData() {
    return this.healthData != null && !this.isLoading;
  }

  get showEmptyState() {
    return !this.selectedAccountId;
  }

  get showLoadingState() {
    return this.isLoading && this.selectedAccountId;
  }

  get factors() {
    return this.healthData?.factors || [];
  }

  get alerts() {
    return this.healthData?.alerts || [];
  }

  get scoreHistory() {
    return this.healthData?.scoreHistory || [];
  }

  get metrics() {
    return this.healthData?.metrics || {};
  }

  get engagements() {
    return this.healthData?.engagements || [];
  }

  get topics() {
    return this.healthData?.topics || [];
  }
}
