# Customer Health Insights

A Salesforce Lightning Web Component app that computes a weighted customer health score with factor analysis, trend tracking, engagement signals, and AI-powered account analysis.

## Overview

Customer Health Insights provides a comprehensive health assessment for any Account in your org. It analyzes Cases, Tasks, Events, Opportunities, Contacts, and EmailMessages to compute a composite health score (0-100) across five weighted factors. The app includes a 12-month score trend chart, engagement and sentiment analysis, churn risk detection, and an AI-powered analysis feature using Salesforce's Einstein Generative AI.

## Features

- **Composite Health Score**: Weighted 0-100 score with letter grade (Excellent/Good/Fair/At Risk/Critical) and trend direction
- **Five-Factor Breakdown**: Support Health (25%), Engagement (25%), Financial Health (20%), Product Adoption (15%), Relationship Depth (15%)
- **Score History Trend**: 12-month line chart with color-coded health zones and interactive tooltips
- **Churn Risk Detection**: Computed from composite score, factor criticality, trend direction, and escalation count
- **Case Metrics**: Open/closed/high-priority case counts with Case Time to Resolution (CTTR)
- **Activity Breakdown**: Calls, meetings, emails, tasks, contacts, and escalations over the last 90 days
- **Engagement Analysis**: Sentiment distribution bars across emails, activities, meetings, cases, and calls
- **Account Signals**: Topic-level sentiment for Product Adoption, Support Experience, Business Growth, Executive Alignment, and Platform Stability
- **AI Health Analysis**: One-click AI-powered account analysis with structured recommendations (powered by Agentforce/Einstein Generative AI)
- **Risk Alerts**: Automated alerts for at-risk factors with actionable recommendations

## Components

### Lightning Web Components
- `customerHealthInsightsApp` - Parent app with account picker, loading states, and data orchestration
- `healthScoreCard` - Circular gauge, metric cards, churn risk, activity breakdown, and case metrics
- `scoreFactorBreakdown` - Five-factor weighted score bars with grades and insights
- `scoreHistoryTrend` - SVG line chart with interactive tooltips and color-coded health zones
- `healthActionAlerts` - AI analysis panel, risk alerts, engagement analysis, and account signals

### Apex Classes
- `CustomerHealthScoreController` - Main controller that queries Account-related records, computes weighted health scores, and generates AI summaries
- `CustomerHealthScoreControllerTest` - Test class with coverage for all scoring methods

## Dependencies

### Key Dependencies
- **Static Resources**: `AgentforceRGBIcon` (included)
- **Salesforce AI Platform**: Einstein Generative AI / Models API (optional, for AI Health Analysis feature only)
- **Standard Objects**: Account, Case, Task, Event, Opportunity, Contact, EmailMessage (no custom objects required)

## Installation

### Prerequisites
- A Salesforce org with API version 65.0+
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
3. Navigate to the **Customer Health Insights** tab, or add the `customerHealthInsightsApp` component to any Lightning App Page

### Einstein Generative AI (Optional)
The AI Health Analysis feature uses the `sfdc_ai__DefaultVertexAIGemini30Flash` model. If Einstein Generative AI is not enabled, the rest of the app works fully without it.

## Usage

1. Open the **Customer Health Insights** tab
2. Search for and select an Account using the account picker
3. The health score, factor breakdown, trend chart, and metrics compute automatically
4. Review risk alerts and engagement/signal analysis
5. Click **Generate** in the AI Health Analysis section for AI-powered recommendations
6. The AI analysis is cached per account for the browser session

## Testing

Run the test class:
```bash
sf apex run test --class-names CustomerHealthScoreControllerTest --result-format human
```

## License

This project is open source and free to use. See LICENSE file for details.

## Support

**No support is provided for this project.**

For non-support requests, please contact Dylan Andersen at dylan.andersen@salesforce.com.

**Author:** Dylan Andersen, Senior Solution Engineer, Agentforce at Salesforce
