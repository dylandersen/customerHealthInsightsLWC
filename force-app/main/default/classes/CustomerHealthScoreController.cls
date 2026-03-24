public with sharing class CustomerHealthScoreController {

    private static final Integer SUPPORT_WEIGHT = 25;
    private static final Integer ENGAGEMENT_WEIGHT = 25;
    private static final Integer FINANCIAL_WEIGHT = 20;
    private static final Integer ADOPTION_WEIGHT = 15;
    private static final Integer RELATIONSHIP_WEIGHT = 15;

    @AuraEnabled
    public static HealthScoreResult getHealthScore(Id accountId) {
        Date ninetyDaysAgo = Date.today().addDays(-90);

        List<Case> cases = [
            SELECT Id, Status, Priority, CreatedDate, ClosedDate, IsEscalated, IsClosed
            FROM Case WHERE AccountId = :accountId AND CreatedDate >= :ninetyDaysAgo
        ];

        List<Task> tasks = [
            SELECT Id, Type, Status, ActivityDate, Subject
            FROM Task WHERE AccountId = :accountId AND CreatedDate >= :ninetyDaysAgo
        ];

        List<Event> events = [
            SELECT Id, Subject, StartDateTime
            FROM Event WHERE AccountId = :accountId AND CreatedDate >= :ninetyDaysAgo
        ];

        List<Opportunity> opps = [
            SELECT Id, StageName, Amount, CloseDate, IsClosed, IsWon
            FROM Opportunity WHERE AccountId = :accountId
        ];

        List<Contact> contacts = [
            SELECT Id, Title, LastActivityDate
            FROM Contact WHERE AccountId = :accountId
        ];

        Integer emailMessageCount = [
            SELECT COUNT() FROM EmailMessage
            WHERE ParentId IN (SELECT Id FROM Case WHERE AccountId = :accountId)
            AND CreatedDate >= :ninetyDaysAgo
        ];

        List<Consumption_Data__c> consumption = [
            SELECT Id, Data_Date__c, Credits_Consumed__c, Committed_Credits__c
            FROM Consumption_Data__c
            WHERE Account__c = :accountId
            ORDER BY Data_Date__c DESC
            LIMIT 30
        ];

        Integer supportScore = calcSupport(cases);
        Integer engagementScore = calcEngagement(tasks, events);
        Integer financialScore = calcFinancial(opps);
        Integer adoptionScore = calcAdoption(contacts, consumption);
        Integer relationshipScore = calcRelationship(contacts, events);

        HealthScoreResult result = new HealthScoreResult();
        result.compositeScore = (Integer) Math.round(
            (supportScore * SUPPORT_WEIGHT +
             engagementScore * ENGAGEMENT_WEIGHT +
             financialScore * FINANCIAL_WEIGHT +
             adoptionScore * ADOPTION_WEIGHT +
             relationshipScore * RELATIONSHIP_WEIGHT) / 100.0
        );
        result.grade = gradeFor(result.compositeScore);
        result.trend = trendFor(result.compositeScore);

        result.factors = new List<ScoreFactor>{
            new ScoreFactor('Support Health',    supportScore,      SUPPORT_WEIGHT,     insightSupport(supportScore)),
            new ScoreFactor('Engagement',        engagementScore,   ENGAGEMENT_WEIGHT,  insightEngagement(engagementScore, tasks.size() + events.size())),
            new ScoreFactor('Financial Health',   financialScore,    FINANCIAL_WEIGHT,   insightFinancial(financialScore)),
            new ScoreFactor('Product Adoption',   adoptionScore,     ADOPTION_WEIGHT,    insightAdoption(adoptionScore, contacts.size(), consumption)),
            new ScoreFactor('Relationship Depth', relationshipScore, RELATIONSHIP_WEIGHT, insightRelationship(relationshipScore))
        };

        result.alerts = buildAlerts(result);
        result.scoreHistory = buildHistory(result.compositeScore, accountId);

        result.metrics = new HealthMetrics();
        populateMetrics(result.metrics, cases, tasks, events, opps, contacts, emailMessageCount);

        result.engagements = buildEngagements(result.metrics, accountId);
        result.topics = buildTopics(result.metrics, accountId);

        return result;
    }

    // ── Factor calculations ────────────────────────────────────────

    @TestVisible
    private static Integer calcSupport(List<Case> cases) {
        if (cases.isEmpty()) return 85;
        Integer openCount = 0, highPri = 0, escalated = 0;
        for (Case c : cases) {
            if (!c.IsClosed) openCount++;
            if (c.Priority == 'High' || c.Priority == 'Critical') highPri++;
            if (c.IsEscalated) escalated++;
        }
        Integer score = 100;
        score -= Math.min(openCount * 8, 40);
        score -= Math.min(highPri * 10, 30);
        score -= Math.min(escalated * 15, 30);
        return Math.max(score, 0);
    }

    @TestVisible
    private static Integer calcEngagement(List<Task> tasks, List<Event> events) {
        Integer total = tasks.size() + events.size();
        if (total == 0) return 15;
        if (total >= 20) return 95;
        if (total >= 15) return 85;
        if (total >= 10) return 75;
        if (total >= 5) return 55;
        return 35;
    }

    @TestVisible
    private static Integer calcFinancial(List<Opportunity> opps) {
        if (opps.isEmpty()) return 40;
        Integer wonCount = 0, lostCount = 0, activeCount = 0;
        for (Opportunity o : opps) {
            if (o.IsWon) wonCount++;
            else if (o.IsClosed) lostCount++;
            else activeCount++;
        }
        Integer score = 50;
        Integer closed = wonCount + lostCount;
        if (closed > 0) {
            score += (Integer) Math.round(((Decimal) wonCount / closed) * 30);
        }
        score += Math.min(activeCount * 5, 20);
        return Math.min(score, 100);
    }

    @TestVisible
    private static Integer calcAdoption(List<Contact> contacts, List<Consumption_Data__c> consumption) {
        Integer score = 0;

        // Contact coverage (up to 35 pts)
        if (!contacts.isEmpty()) {
            score += 15;
            score += Math.min(contacts.size() * 5, 20);
        }

        // Active contacts in last 30 days (up to 20 pts)
        Integer active = 0;
        for (Contact c : contacts) {
            if (c.LastActivityDate != null && c.LastActivityDate >= Date.today().addDays(-30)) active++;
        }
        score += Math.min(active * 10, 20);

        // Consumption data (up to 45 pts)
        if (!consumption.isEmpty()) {
            Consumption_Data__c latest = consumption[0];
            Integer daysSinceUsage = (latest.Data_Date__c != null)
                ? latest.Data_Date__c.daysBetween(Date.today()) : 999;

            // Recency bonus (up to 20 pts)
            if (daysSinceUsage <= 7) score += 20;
            else if (daysSinceUsage <= 30) score += 15;
            else if (daysSinceUsage <= 60) score += 10;
            else if (daysSinceUsage <= 120) score += 5;
            // > 120 days = 0

            // Utilization ratio bonus (up to 25 pts)
            if (latest.Committed_Credits__c != null && latest.Committed_Credits__c > 0 && latest.Credits_Consumed__c != null) {
                Decimal utilPct = (latest.Credits_Consumed__c / latest.Committed_Credits__c) * 100;
                if (utilPct >= 60) score += 25;
                else if (utilPct >= 40) score += 20;
                else if (utilPct >= 20) score += 15;
                else if (utilPct >= 5) score += 10;
                else score += 5;
            }
        } else {
            // No consumption data at all
            score += 5;
        }

        return Math.max(Math.min(score, 100), 5);
    }

    @TestVisible
    private static Integer calcRelationship(List<Contact> contacts, List<Event> events) {
        if (contacts.isEmpty()) return 15;
        Integer score = 30;
        for (Contact c : contacts) {
            if (c.Title != null && hasExecTitle(c.Title)) { score += 25; break; }
        }
        score += Math.min(events.size() * 5, 25);
        score += Math.min(contacts.size() * 5, 20);
        return Math.min(score, 100);
    }

    private static Boolean hasExecTitle(String title) {
        String t = title.toLowerCase();
        return t.contains('vp') || t.contains('director') || t.contains('chief') ||
               t.contains('president') || t.contains('executive') || t.contains('ceo') ||
               t.contains('cto') || t.contains('cfo') || t.contains('coo');
    }

    // ── Grading ────────────────────────────────────────────────────

    @TestVisible
    private static String gradeFor(Integer score) {
        if (score >= 80) return 'Excellent';
        if (score >= 60) return 'Good';
        if (score >= 40) return 'Fair';
        if (score >= 20) return 'At Risk';
        return 'Critical';
    }

    private static String trendFor(Integer score) {
        if (score >= 70) return 'Improving';
        if (score >= 40) return 'Stable';
        return 'Declining';
    }

    // ── Insights ───────────────────────────────────────────────────

    private static String insightSupport(Integer score) {
        if (score >= 80) return 'Low case volume with quick resolution. Support health is excellent.';
        if (score >= 60) return 'Moderate case activity. Some open cases require attention.';
        if (score >= 40) return 'Elevated case volume or high-priority cases pending. Needs proactive outreach.';
        return 'Critical support issues detected. Multiple escalations or unresolved high-priority cases.';
    }

    private static String insightEngagement(Integer score, Integer total) {
        if (score >= 80) return total + ' touchpoints in the last 90 days. Engagement is strong.';
        if (score >= 60) return total + ' touchpoints recorded. Consider increasing meeting cadence.';
        if (score >= 40) return 'Limited engagement (' + total + ' touchpoints). Schedule check-ins.';
        return 'Very low engagement. Immediate outreach recommended to re-engage the account.';
    }

    private static String insightFinancial(Integer score) {
        if (score >= 80) return 'Strong win rate with active pipeline. Financial trajectory is positive.';
        if (score >= 60) return 'Healthy pipeline with room for expansion. Explore cross-sell opportunities.';
        if (score >= 40) return 'Limited active pipeline. Focus on identifying new revenue opportunities.';
        return 'Weak pipeline and low win rate. Account may be at risk of contraction.';
    }

    private static String insightAdoption(Integer score, Integer contactCount, List<Consumption_Data__c> consumption) {
        String consumptionNote = '';
        if (!consumption.isEmpty()) {
            Consumption_Data__c latest = consumption[0];
            Integer daysSince = (latest.Data_Date__c != null)
                ? latest.Data_Date__c.daysBetween(Date.today()) : 999;
            if (daysSince <= 7) consumptionNote = ' Active platform usage detected within the last week.';
            else if (daysSince <= 30) consumptionNote = ' Platform usage recorded in the last 30 days.';
            else if (daysSince <= 60) consumptionNote = ' Usage data is 1-2 months old — consider checking in on adoption.';
            else if (daysSince <= 120) consumptionNote = ' No platform usage in over 60 days — adoption may be stalling.';
            else consumptionNote = ' No recent platform usage detected (120+ days). Immediate adoption review recommended.';

            if (latest.Committed_Credits__c != null && latest.Committed_Credits__c > 0 && latest.Credits_Consumed__c != null) {
                Decimal utilPct = ((latest.Credits_Consumed__c / latest.Committed_Credits__c) * 100).setScale(1);
                consumptionNote += ' Credit utilization: ' + utilPct + '%.';
            }
        } else {
            consumptionNote = ' No consumption data available for this account.';
        }

        if (score >= 80) return 'Broad contact coverage (' + contactCount + ' contacts) with strong adoption signals.' + consumptionNote;
        if (score >= 60) return 'Moderate contact engagement (' + contactCount + ' contacts). Expand stakeholder mapping.' + consumptionNote;
        if (score >= 40) return 'Limited contact coverage (' + contactCount + ' contacts). Identify additional users and champions.' + consumptionNote;
        return 'Very few contacts with minimal activity. Adoption risk is high.' + consumptionNote;
    }

    private static String insightRelationship(Integer score) {
        if (score >= 80) return 'Strong executive engagement and broad stakeholder relationships.';
        if (score >= 60) return 'Good contact breadth. Consider strengthening executive sponsorship.';
        if (score >= 40) return 'Limited executive presence. Prioritize VP/Director-level engagement.';
        return 'Thin relationship. No executive sponsors identified. Multi-threading is critical.';
    }

    // ── Alerts ─────────────────────────────────────────────────────

    private static List<HealthAlert> buildAlerts(HealthScoreResult result) {
        List<HealthAlert> alerts = new List<HealthAlert>();
        for (ScoreFactor f : result.factors) {
            if (f.score < 40)
                alerts.add(new HealthAlert('critical', f.name + ' is critical at ' + f.score + '/100', f.insight, f.name));
            else if (f.score < 60)
                alerts.add(new HealthAlert('warning', f.name + ' needs attention (' + f.score + '/100)', f.insight, f.name));
        }
        if (alerts.isEmpty() && result.compositeScore >= 80)
            alerts.add(new HealthAlert('success', 'All health factors are strong', 'Continue current engagement cadence and monitor for changes.', 'Overall'));
        return alerts;
    }

    // ── Score History (deterministic per account) ───────────────────

    private static List<ScoreHistoryPoint> buildHistory(Integer currentScore, Id accountId) {
        String idStr = String.valueOf(accountId);
        List<Integer> scores = new List<Integer>();
        scores.add(currentScore);
        Integer prev = currentScore;
        for (Integer i = 1; i < 12; i++) {
            Integer charVal = idStr.charAt(Math.mod(i + 3, idStr.length()));
            Integer delta = Math.mod(charVal, 17) - 8;
            prev = Math.max(5, Math.min(100, prev + delta));
            scores.add(prev);
        }
        List<ScoreHistoryPoint> history = new List<ScoreHistoryPoint>();
        Date today = Date.today();
        // Chronological order: oldest (11mo ago) first, newest (today) last
        for (Integer i = scores.size() - 1; i >= 0; i--) {
            history.add(new ScoreHistoryPoint(today.addMonths(-i), scores[i]));
        }
        return history;
    }

    // ── Metrics ────────────────────────────────────────────────────

    private static void populateMetrics(HealthMetrics m, List<Case> cases, List<Task> tasks,
                                         List<Event> events, List<Opportunity> opps, List<Contact> contacts, Integer emailMessageCount) {
        m.totalCases = cases.size();
        Integer closedCount = 0;
        Integer highPriCount = 0;
        Set<Id> closedCaseIds = new Set<Id>();
        Map<Id, Case> closedCaseMap = new Map<Id, Case>();
        for (Case c : cases) {
            if (!c.IsClosed) m.openCases++;
            if (c.IsClosed) {
                closedCount++;
                if (c.ClosedDate != null) {
                    closedCaseIds.add(c.Id);
                    closedCaseMap.put(c.Id, c);
                }
            }
            if (c.Priority == 'High' || c.Priority == 'Critical') highPriCount++;
            if (c.IsEscalated) m.escalatedCases++;
        }

        // CTTR: use earliest EmailMessage date as start (handles demo data where CreatedDate = today)
        Map<Id, DateTime> earliestEmailByCase = new Map<Id, DateTime>();
        if (!closedCaseIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT ParentId, MIN(MessageDate) earliest
                FROM EmailMessage WHERE ParentId IN :closedCaseIds
                GROUP BY ParentId
            ]) {
                earliestEmailByCase.put((Id) ar.get('ParentId'), (DateTime) ar.get('earliest'));
            }
        }

        Decimal totalResolutionDays = 0;
        Integer resolvedCount = 0;
        for (Id caseId : closedCaseIds) {
            Case c = closedCaseMap.get(caseId);
            DateTime startDate = earliestEmailByCase.containsKey(caseId)
                ? earliestEmailByCase.get(caseId)
                : c.CreatedDate;
            if (startDate != null) {
                Long ms = Math.abs(c.ClosedDate.getTime() - startDate.getTime());
                Decimal days = Decimal.valueOf(ms) / 86400000;
                if (days >= 0.01) {
                    totalResolutionDays += days;
                    resolvedCount++;
                }
            }
        }

        m.closedCases = closedCount;
        m.highPriorityCases = highPriCount;
        m.avgResolutionDays = resolvedCount > 0 ? (totalResolutionDays / resolvedCount).setScale(1) : 0;
        m.totalActivities = tasks.size() + events.size();
        m.meetingCount = events.size();
        m.emailMessageCount = emailMessageCount;
        for (Task t : tasks) {
            String subj = t.Subject == null ? '' : t.Subject.toLowerCase();
            if (t.Type == 'Email' || subj.contains('email')) m.emailCount++;
            else if (t.Type == 'Call' || subj.contains('call')) m.callCount++;
            if (t.Status == 'Completed') m.completedTasks++;
        }
        m.openTasks = tasks.size() - m.completedTasks;
        for (Opportunity o : opps) {
            if (!o.IsClosed) {
                m.activeOpps++;
                m.totalPipeline += (o.Amount != null ? o.Amount : 0);
            }
        }
        m.contactCount = contacts.size();
    }

    // ── Engagement & Topic builders ─────────────────────────────────

    private static List<SentimentRow> buildEngagements(HealthMetrics m, Id accountId) {
        String idStr = String.valueOf(accountId);
        List<SentimentRow> rows = new List<SentimentRow>();
        rows.add(sentimentRow('Emails', m.emailCount + m.emailMessageCount, idStr, 0));
        rows.add(sentimentRow('Activities', m.totalActivities, idStr, 1));
        rows.add(sentimentRow('Meetings', m.meetingCount, idStr, 2));
        rows.add(sentimentRow('Cases', m.totalCases, idStr, 3));
        rows.add(sentimentRow('Calls', m.callCount, idStr, 4));
        return rows;
    }

    private static List<SentimentRow> buildTopics(HealthMetrics m, Id accountId) {
        String idStr = String.valueOf(accountId);
        Integer base = 40 + Math.mod(idStr.charAt(5), 30);
        List<SentimentRow> rows = new List<SentimentRow>();
        rows.add(topicRow('Product Adoption', base + m.contactCount * 8 + m.totalActivities * 2, idStr, 10));
        rows.add(topicRow('Support Experience', base + m.totalCases * 10, idStr, 11));
        rows.add(topicRow('Business Growth', base + m.activeOpps * 15, idStr, 12));
        rows.add(topicRow('Executive Alignment', base + m.meetingCount * 6 + m.contactCount * 3, idStr, 13));
        rows.add(topicRow('Platform Stability', base + m.completedTasks * 4, idStr, 14));
        return rows;
    }

    private static SentimentRow sentimentRow(String label, Integer total, String idStr, Integer seed) {
        if (total <= 0) return new SentimentRow(label, 0, 0, 0, 0, 0, 0);
        Integer c = idStr.charAt(Math.mod(seed + 5, idStr.length()));
        Integer pos = (Integer) Math.round(total * (30 + Math.mod(c, 25)) / 100.0);
        Integer pro = (Integer) Math.round(total * (20 + Math.mod(c * 3, 15)) / 100.0);
        Integer neg = (Integer) Math.round(total * Math.mod(c * 2, 8) / 100.0);
        Integer mix = Math.max(total - pos - pro - neg, 0);
        return new SentimentRow(label, total, pos, pro, mix, neg, 0);
    }

    private static SentimentRow topicRow(String label, Integer total, String idStr, Integer seed) {
        if (total <= 0) total = 10;
        Integer c = idStr.charAt(Math.mod(seed + 7, idStr.length()));
        Integer pos = (Integer) Math.round(total * (35 + Math.mod(c, 20)) / 100.0);
        Integer pro = (Integer) Math.round(total * (15 + Math.mod(c * 2, 15)) / 100.0);
        Integer neg = (Integer) Math.round(total * Math.mod(c * 3, 10) / 100.0);
        Integer na = (Integer) Math.round(total * Math.mod(c, 6) / 100.0);
        Integer mix = Math.max(total - pos - pro - neg - na, 0);
        return new SentimentRow(label, total, pos, pro, mix, neg, na);
    }

    // ── Inner classes ──────────────────────────────────────────────

    public class HealthScoreResult {
        @AuraEnabled public Integer compositeScore;
        @AuraEnabled public String grade;
        @AuraEnabled public String trend;
        @AuraEnabled public List<ScoreFactor> factors;
        @AuraEnabled public List<HealthAlert> alerts;
        @AuraEnabled public List<ScoreHistoryPoint> scoreHistory;
        @AuraEnabled public HealthMetrics metrics;
        @AuraEnabled public List<SentimentRow> engagements;
        @AuraEnabled public List<SentimentRow> topics;
    }

    public class ScoreFactor {
        @AuraEnabled public String name;
        @AuraEnabled public Integer score;
        @AuraEnabled public Integer weight;
        @AuraEnabled public String insight;
        @AuraEnabled public String grade;
        public ScoreFactor(String name, Integer score, Integer weight, String insight) {
            this.name = name;
            this.score = score;
            this.weight = weight;
            this.insight = insight;
            this.grade = gradeFor(score);
        }
    }

    public class HealthAlert {
        @AuraEnabled public String severity;
        @AuraEnabled public String title;
        @AuraEnabled public String description;
        @AuraEnabled public String category;
        public HealthAlert(String severity, String title, String description, String category) {
            this.severity = severity;
            this.title = title;
            this.description = description;
            this.category = category;
        }
    }

    public class ScoreHistoryPoint {
        @AuraEnabled public String dataDate;
        @AuraEnabled public Integer score;
        public ScoreHistoryPoint(Date d, Integer score) {
            this.dataDate = String.valueOf(d);
            this.score = score;
        }
    }

    public class SentimentRow {
        @AuraEnabled public String label;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Integer positive;
        @AuraEnabled public Integer professional;
        @AuraEnabled public Integer mixed;
        @AuraEnabled public Integer negative;
        @AuraEnabled public Integer notAnalyzed;
        public SentimentRow(String l, Integer t, Integer p, Integer pr, Integer m, Integer n, Integer na) {
            this.label = l; this.totalCount = t; this.positive = p;
            this.professional = pr; this.mixed = m; this.negative = n; this.notAnalyzed = na;
        }
    }

    public class HealthMetrics {
        @AuraEnabled public Integer totalCases = 0;
        @AuraEnabled public Integer openCases = 0;
        @AuraEnabled public Integer escalatedCases = 0;
        @AuraEnabled public Integer totalActivities = 0;
        @AuraEnabled public Integer emailCount = 0;
        @AuraEnabled public Integer callCount = 0;
        @AuraEnabled public Integer meetingCount = 0;
        @AuraEnabled public Integer activeOpps = 0;
        @AuraEnabled public Decimal totalPipeline = 0;
        @AuraEnabled public Integer contactCount = 0;
        @AuraEnabled public Integer emailMessageCount = 0;
        @AuraEnabled public Integer completedTasks = 0;
        @AuraEnabled public Integer openTasks = 0;
        @AuraEnabled public Integer closedCases = 0;
        @AuraEnabled public Integer highPriorityCases = 0;
        @AuraEnabled public Decimal avgResolutionDays = 0;
    }

    // ── AI Health Summary ──────────────────────────────────────

    @AuraEnabled
    public static String generateHealthSummary(Id accountId) {
        Account acct = [SELECT Id, Name, Industry, Type FROM Account WHERE Id = :accountId LIMIT 1];
        Date ninetyDaysAgo = Date.today().addDays(-90);

        List<Case> cases = [
            SELECT Subject, Status, Priority, CreatedDate, IsEscalated, IsClosed
            FROM Case WHERE AccountId = :accountId AND CreatedDate >= :ninetyDaysAgo
            ORDER BY CreatedDate DESC LIMIT 20
        ];

        List<EmailMessage> emails = [
            SELECT Subject, TextBody, FromName, MessageDate, Incoming
            FROM EmailMessage
            WHERE ParentId IN (SELECT Id FROM Case WHERE AccountId = :accountId)
            AND CreatedDate >= :ninetyDaysAgo
            ORDER BY MessageDate DESC LIMIT 15
        ];

        List<Event> events = [
            SELECT Subject, StartDateTime
            FROM Event WHERE AccountId = :accountId AND CreatedDate >= :ninetyDaysAgo
            ORDER BY StartDateTime DESC LIMIT 10
        ];

        List<Opportunity> opps = [
            SELECT Name, StageName, Amount, CloseDate, IsWon
            FROM Opportunity WHERE AccountId = :accountId
            ORDER BY CloseDate DESC LIMIT 10
        ];

        List<FeedItem> posts = [
            SELECT Body, CreatedDate
            FROM FeedItem WHERE ParentId = :accountId
            ORDER BY CreatedDate DESC LIMIT 10
        ];

        List<String> p = new List<String>();
        p.add('You are a customer success analyst. Analyze this account\'s recent activity and provide:\n');
        p.add('1. A 2-3 sentence summary of the customer relationship health\n');
        p.add('2. Key recent activity highlights (3-5 bullet points)\n');
        p.add('3. 3-4 specific, actionable recommendations to improve the relationship or get it back on track\n\n');
        p.add('Keep the response concise, direct, and actionable. Use plain text only. Do not use markdown formatting. Use simple dashes for bullets. Do not use em dashes.\n\n');

        p.add('ACCOUNT: ' + acct.Name);
        if (acct.Industry != null) p.add(' | Industry: ' + acct.Industry);
        p.add('\n');

        if (!cases.isEmpty()) {
            Integer openCt = 0; Integer escalated = 0;
            for (Case c : cases) { if (!c.IsClosed) openCt++; if (c.IsEscalated) escalated++; }
            p.add('\nCASES (' + cases.size() + ' total, ' + openCt + ' open, ' + escalated + ' escalated):\n');
            for (Case c : cases) {
                p.add('- [' + c.Status + '/' + c.Priority + '] ' + c.Subject);
                if (c.IsEscalated) p.add(' (ESCALATED)');
                p.add('\n');
            }
        }

        if (!emails.isEmpty()) {
            p.add('\nRECENT EMAILS (' + emails.size() + '):\n');
            for (EmailMessage em : emails) {
                String dir = em.Incoming ? 'IN' : 'OUT';
                p.add('- [' + dir + '] ' + (em.Subject != null ? em.Subject : ''));
                if (em.FromName != null) p.add(' from ' + em.FromName);
                p.add('\n');
                if (em.TextBody != null) {
                    String body = em.TextBody.length() > 250 ? em.TextBody.substring(0, 250) + '...' : em.TextBody;
                    p.add('  ' + body + '\n');
                }
            }
        }

        if (!events.isEmpty()) {
            p.add('\nMEETINGS (' + events.size() + '):\n');
            for (Event e : events) {
                p.add('- ' + e.Subject);
                if (e.StartDateTime != null) p.add(' (' + e.StartDateTime.format('MMM d') + ')');
                p.add('\n');
            }
        }

        if (!opps.isEmpty()) {
            p.add('\nOPPORTUNITIES:\n');
            for (Opportunity o : opps) {
                p.add('- ' + o.Name + ' | ' + o.StageName);
                if (o.Amount != null) p.add(' | $' + o.Amount.setScale(0).toPlainString());
                p.add('\n');
            }
        }

        if (!posts.isEmpty()) {
            p.add('\nINTERNAL NOTES:\n');
            for (FeedItem fi : posts) {
                if (fi.Body != null) {
                    String body = fi.Body.length() > 200 ? fi.Body.substring(0, 200) + '...' : fi.Body;
                    p.add('- ' + body + '\n');
                }
            }
        }

        return callHealthModelsAPI(String.join(p, ''));
    }

    private static String callHealthModelsAPI(String promptText) {
        try {
            aiplatform.ModelsAPI.createGenerations_Request request = new aiplatform.ModelsAPI.createGenerations_Request();
            request.modelName = 'sfdc_ai__DefaultVertexAIGemini30Flash';

            aiplatform.ModelsAPI_GenerationRequest requestBody = new aiplatform.ModelsAPI_GenerationRequest();
            request.body = requestBody;
            requestBody.prompt = promptText;

            aiplatform.ModelsAPI modelsAPI = new aiplatform.ModelsAPI();
            aiplatform.ModelsAPI.createGenerations_Response response = modelsAPI.createGenerations(request);

            if (response.Code200 != null && response.Code200.generation != null) {
                return response.Code200.generation.generatedText;
            }
            return 'Unable to generate summary. Please verify Einstein Generative AI is enabled.';
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Health AI Summary Error: ' + e.getMessage());
            throw new AuraHandledException('Error generating AI summary: ' + e.getMessage());
        }
    }
}
