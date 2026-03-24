# Customer Health Insights

A Salesforce Lightning Web Component app that computes a weighted customer health score with factor analysis, trend tracking, engagement signals, and AI-powered account analysis.

![Salesforce API 62.0](https://img.shields.io/badge/Salesforce%20API-62.0-blue)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Screenshot

> Add a screenshot of the app here:
>
> ![Customer Health Insights](docs/screenshot.png)

## Overview

Customer Health Insights provides a comprehensive health assessment for any Account in your org. It analyzes Cases, Tasks, Events, Opportunities, Contacts, and EmailMessages to compute a composite health score (0-100) across five weighted factors. The app includes a 12-month score trend chart, engagement and sentiment analysis, churn risk detection, and an AI-powered analysis feature using Salesforce's Einstein Generative AI.

## Features

- **Composite Health Score**: Weighted 0-100 score with letter grade (Excellent/Good/Fair/At Risk/Critical) and trend direction
- **Five-Factor Breakdown**: Support Health (25%), Engagement (25%), Financial Health (20%), Product Adoption (15%), Relationship Depth (15%)
- **Score History Trend**: 12-month line chart with color-coded health zones and interactive tooltips
- **Churn Risk Detection**: Computed from composite score, factor criticality, trend direction, and escalation count
- **Case Metrics**: Open/closed/high-priority case counts with average Case Time to Resolution (CTTR)
- **Activity Breakdown**: Calls, meetings, emails, tasks, contacts, and escalations over the last 90 days
- **Engagement Analysis**: Sentiment distribution bars across emails, activities, meetings, cases, and calls
- **Account Signals**: Topic-level sentiment for Product Adoption, Support Experience, Business Growth, Executive Alignment, and Platform Stability
- **AI Health Analysis**: One-click AI-powered account analysis with structured recommendations (powered by Agentforce/Einstein Generative AI)
- **Risk Alerts**: Automated alerts for at-risk factors with actionable recommendations

## How Scoring Works

All scoring is based on real-time queries against standard Salesforce objects. Activities (Cases, Tasks, Events, EmailMessages) are scoped to the **last 90 days**. Opportunities and Contacts are queried without a time filter.

### Factor Weights and Calculation

| Factor | Weight | Data Sources | How It's Calculated |
|--------|--------|-------------|---------------------|
| **Support Health** | 25% | Cases | Starts at 100. Deducts up to 40 pts for open cases (-8 each), up to 30 pts for high-priority cases (-10 each), and up to 30 pts for escalations (-15 each). No cases = 85. |
| **Engagement** | 25% | Tasks, Events | Activity count thresholds: 0 = 15, 1-4 = 35, 5-9 = 55, 10-14 = 75, 15-19 = 85, 20+ = 95. |
| **Financial Health** | 20% | Opportunities | Base of 50, plus up to 30 pts from win rate (won / total closed), plus up to 20 pts for active pipeline (5 per open opp). No opps = 40. |
| **Product Adoption** | 15% | Contacts | Base of 30, plus up to 40 pts for contact count (8 per contact), plus up to 30 pts for recently active contacts (10 per contact active in last 30 days). No contacts = 20. |
| **Relationship Depth** | 15% | Contacts, Events | Base of 30, plus 25 pts if any contact has an executive title (VP, Director, Chief, etc.), plus up to 25 pts for meetings (5 per event), plus up to 20 pts for contact breadth (5 per contact). No contacts = 15. |

### Composite Score

The composite score is the weighted average of all five factors:

```
compositeScore = (support * 25 + engagement * 25 + financial * 20 + adoption * 15 + relationship * 15) / 100
```

### Grading Scale

| Score Range | Grade |
|-------------|-------|
| 80-100 | Excellent |
| 60-79 | Good |
| 40-59 | Fair |
| 20-39 | At Risk |
| 0-19 | Critical |

### Score History

The 12-month trend chart is **deterministic per account** — it derives historical scores from the current composite score and the Account's record ID. It does not store or persist historical scores. This means the trend is stable for a given account but recalculates if the underlying data changes.

## Components

### Lightning Web Components
- `customerHealthInsightsApp` — Parent app with account picker, loading states, and data orchestration
- `healthScoreCard` — Circular gauge, metric cards, churn risk, activity breakdown, and case metrics
- `scoreFactorBreakdown` — Five-factor weighted score bars with grades and insights
- `scoreHistoryTrend` — SVG line chart with interactive tooltips and color-coded health zones
- `healthActionAlerts` — AI analysis panel, risk alerts, engagement analysis, and account signals

### Apex Classes
- `CustomerHealthScoreController` — Main controller that queries Account-related records, computes weighted health scores, and generates AI summaries
- `CustomerHealthScoreControllerTest` — Test class with coverage for all scoring methods

### Additional Metadata
- `Customer_Health_Insights.flexipage-meta.xml` — Lightning App Page (auto-deployed)
- `Customer_Health_Insights.tab-meta.xml` — Custom Tab (auto-deployed)
- `AgentforceRGBIcon.png` — Static resource used in the AI analysis panel

## Dependencies

- **Static Resources**: `AgentforceRGBIcon` (included in this repo)
- **Salesforce AI Platform**: Einstein Generative AI / Models API (optional — only needed for the AI Health Analysis feature)
- **Standard Objects**: Account, Case, Task, Event, Opportunity, Contact, EmailMessage (no custom objects required)

## Installation

### Prerequisites
- A Salesforce org with API version 62.0+
- Einstein Generative AI enabled (optional, only needed for the AI Health Analysis feature)

### Deployment Steps

1. Clone this repository:
   ```bash
   git clone https://github.com/dylandersen/customerHealthInsightsLWC.git
   ```
2. Deploy to your Salesforce org:
   ```bash
   sf project deploy start --source-dir force-app
   ```
3. The deployment automatically creates:
   - A **Customer Health Insights** Lightning App Page
   - A **Customer Health Insights** custom Tab
4. Navigate to the **Customer Health Insights** tab in your org

To add the component to a Record Page instead, open any Account record page in Lightning App Builder and drag the `customerHealthInsightsApp` component onto the page.

### Einstein Generative AI (Optional)
The AI Health Analysis feature uses the `sfdc_ai__DefaultVertexAIGemini30Flash` model. If your org uses a different model name, update the `modelName` value in `CustomerHealthScoreController.callHealthModelsAPI()`. If Einstein Generative AI is not enabled, the rest of the app works fully without it.

## Usage

1. Open the **Customer Health Insights** tab
2. Search for and select an Account using the account picker
3. The health score, factor breakdown, trend chart, and metrics compute automatically
4. Review risk alerts and engagement/signal analysis
5. Click **Generate** in the AI Health Analysis section for AI-powered recommendations
6. The AI analysis is cached per account for the browser session

## Known Limitations

- **Score history is simulated** — The 12-month trend is derived from the current score and Account ID, not from stored historical data. It provides a stable but synthetic trend line.
- **90-day activity window is fixed** — Cases, Tasks, Events, and EmailMessages are always scoped to the last 90 days. This is not configurable.
- **AI model name is hardcoded** — The model `sfdc_ai__DefaultVertexAIGemini30Flash` is set in Apex. If your org provisions a different model, you'll need to update the class.
- **No custom objects required** — The app relies entirely on standard objects, but this means it cannot track health scores over time without extending the data model.

## Testing

Run the test class:
```bash
sf apex run test --class-names CustomerHealthScoreControllerTest --result-format human
```

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Support

**No support is provided for this project.**

For non-support requests, please contact Dylan Andersen at dylan.andersen@salesforce.com.

**Author:** Dylan Andersen, Senior Solution Engineer, Agentforce at Salesforce
