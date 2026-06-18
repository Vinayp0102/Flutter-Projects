# Local Growth OS - User Flow Documentation

## Overview

This document details the complete user flows for Local Growth OS, covering all primary user personas and their interactions with the system.

---

## 1. Onboarding Flow

### 1.1 New Business Registration Flow

```
START
  │
  ▼
[Landing Page] → [Click "Start Free Trial"]
  │
  ▼
[Sign Up Form]
  ├── Enter Business Name
  ├── Enter Email
  ├── Enter Phone Number
  ├── Create Password
  └── Select Industry (Salon/Clinic/Gym/Coaching/Real Estate/Packers & Movers)
  │
  ▼
[Email Verification]
  │
  ▼
[Business Profile Setup]
  ├── Upload Logo
  ├── Set Business Hours
  ├── Add Location(s)
  └── Configure Timezone
  │
  ▼
[Industry Template Selection]
  │
  ▼
[Team Invitation] (Optional - Skip allowed)
  ├── Invite Team Members via Email
  └── Assign Roles
  │
  ▼
[Integration Setup] (Optional - Skip allowed)
  ├── Connect Google My Business
  ├── Connect Facebook Page
  ├── Connect Calendar
  └── Configure SMS/Email Settings
  │
  ▼
[Tutorial/Walkthrough]
  │
  ▼
[DASHBOARD] → Onboarding Complete
```

### 1.2 Team Member Invitation Flow

```
ADMIN: [Dashboard] → [Settings] → [Team Management] → [Invite Member]
  │
  ▼
[Enter Details]
  ├── Name
  ├── Email
  └── Select Role (Admin/Manager/Agent/Front Desk)
  │
  ▼
[Send Invitation Email]
  │
  ▼
[TEAM MEMBER: Receive Email] → [Click Activation Link]
  │
  ▼
[Set Password] → [Complete Profile]
  │
  ▼
[Access Granted to Dashboard]
```

---

## 2. Lead Management Flow

### 2.1 Lead Capture Flow (Multiple Sources)

#### Flow A: Web Form Submission
```
[Prospect visits business website]
  │
  ▼
[Fills out Contact Form]
  │
  ▼
[Form submits to Local Growth OS API]
  │
  ▼
[System checks for duplicates (phone/email)]
  │
  ├─→ [DUPLICATE FOUND] → [Update existing lead record] → [Add to timeline]
  │
  └─→ [NEW LEAD] → [Create lead record]
        │
        ▼
      [Assign to pipeline stage "New"]
        │
        ▼
      [Trigger welcome workflow]
        │
        ▼
      [Notify assigned team member]
```

#### Flow B: Manual Lead Entry
```
[User: Front Desk/Agent]
  │
  ▼
[Dashboard] → [Leads] → [+ Add Lead]
  │
  ▼
[Enter Lead Information]
  ├── First Name, Last Name
  ├── Phone Number*
  ├── Email
  ├── Source (Walk-in/Phone/Referral/Social Media)
  ├── Service Interested In
  ├── Notes
  └── Assign To (Team Member)
  │
  ▼
[Save Lead]
  │
  ▼
[Lead created in "New" stage]
  │
  ▼
[Trigger appropriate workflow based on source]
```

#### Flow C: Facebook Lead Ads Integration
```
[Prospect clicks Facebook Ad]
  │
  ▼
[Fills Facebook Lead Form]
  │
  ▼
[Facebook sends webhook to Local Growth OS]
  │
  ▼
[System processes lead data]
  │
  ▼
[Create/Update lead record]
  │
  ▼
[Tag as "Facebook Ads"]
  │
  ▼
[Trigger Facebook-specific workflow]
```

### 2.2 Lead Pipeline Movement Flow

```
[User views Pipeline Board]
  │
  ▼
[Drag lead from one stage to another]
  │
  ▼
[System updates lead stage]
  │
  ▼
[Check for stage-change triggers]
  │
  ├─→ [TRIGGER EXISTS] → [Execute workflow actions]
  │                        ├── Send SMS/Email
  │                        ├── Create task
  │                        └── Update lead score
  │
  └─→ [NO TRIGGER] → [Log stage change]
        │
        ▼
      [Update pipeline metrics]
```

### 2.3 Lead Follow-up Flow

```
[System detects lead in current stage > X days]
  │
  ▼
[Flag as "Stale Lead"]
  │
  ▼
[Send notification to assigned agent]
  │
  ▼
[Agent receives alert in dashboard/notification]
  │
  ▼
[Agent reviews lead history]
  │
  ▼
[Agent takes action]
  ├── Send manual message
  ├── Schedule call
  ├── Update status
  └── Mark as lost
  │
  ▼
[System logs activity]
  │
  ▼
[Reset stale timer]
```

---

## 3. Automation Workflow Flow

### 3.1 Workflow Creation Flow

```
[User: Admin/Manager]
  │
  ▼
[Dashboard] → [Automation] → [Create Workflow]
  │
  ▼
[Select Workflow Type]
  ├── Lead Nurture
  ├── Post-Service Follow-up
  ├── Review Request
  ├── Appointment Reminder
  └── Re-engagement Campaign
  │
  ▼
[Configure Trigger]
  ├── Time-based (X days after event)
  ├── Action-based (status change, form submit)
  └── Date-based (birthday, anniversary)
  │
  ▼
[Build Workflow Canvas]
  │
  ├─→ [Add Action Node]
  │     ├── Send SMS
  │     ├── Send Email
  │     ├── Wait (delay)
  │     ├── Update Lead Status
  │     ├── Assign to Team Member
  │     └── Add Tag
  │
  ├─→ [Add Condition Node]
  │     ├── If/Else branching
  │     ├── Based on lead properties
  │     └── Based on previous actions
  │
  └─→ [Connect Nodes]
        │
        ▼
      [Visual workflow builder]
  │
  ▼
[Test Workflow] (Optional)
  │
  ▼
[Activate Workflow]
  │
  ▼
[Workflow is live and monitoring triggers]
```

### 3.2 Workflow Execution Flow

```
[Event occurs in system]
  │
  ▼
[System checks active workflows for matching triggers]
  │
  ▼
[Workflow instance created for specific lead/customer]
  │
  ▼
[Execute first action]
  │
  ▼
[Wait for delay (if specified)]
  │
  ▼
[Check conditions]
  │
  ├─→ [Condition TRUE] → [Follow TRUE path]
  │
  └─→ [Condition FALSE] → [Follow FALSE path / Exit]
        │
        ▼
      [Continue executing actions]
        │
        ▼
      [Log each action completion]
        │
        ▼
      [Handle failures]
        ├── Retry (up to 3 times)
        └── Alert admin if critical failure
        │
        ▼
      [Workflow completes or reaches end node]
```

---

## 4. Review Management Flow

### 4.1 Review Aggregation Flow

```
[System scheduled job runs every hour]
  │
  ▼
[For each connected business location]
  │
  ├─→ [Call Google My Business API]
  │     └── Fetch new reviews
  │
  ├─→ [Call Facebook Graph API]
  │     └── Fetch new reviews
  │
  └─→ [Call Yelp API] (if applicable)
        └── Fetch new reviews
  │
  ▼
[Store reviews in database]
  │
  ▼
[Check for negative reviews (≤3 stars)]
  │
  ├─→ [NEGATIVE REVIEW] → [Send immediate alert to admin]
  │                        └── Push notification + Email
  │
  └─→ [ALL REVIEWS] → [Update dashboard metrics]
        │
        ▼
      [Calculate average rating]
        │
        ▼
      [Update review count]
```

### 4.2 Review Request Flow

```
[Trigger: Service completed / Appointment ended]
  │
  ▼
[Wait configured delay (e.g., 2 hours)]
  │
  ▼
[Check customer eligibility]
  ├── Has not received request in last 30 days
  ├── Has valid phone/email
  └── Has not opted out
  │
  ▼
[Generate personalized review request message]
  │
  ▼
[Send via preferred channel (SMS/Email)]
  │
  ▼
[Include direct links to review platforms]
  │
  ▼
[Track link clicks]
  │
  ▼
[If customer clicks link → Log intent]
  │
  ▼
[After 7 days, check if review was left]
  │
  ├─→ [REVIEW LEFT] → [Thank customer message]
  │
  └─→ [NO REVIEW] → [Send reminder (optional)]
```

### 4.3 Review Response Flow

```
[User: Admin/Manager]
  │
  ▼
[Dashboard] → [Reviews] → [View All Reviews]
  │
  ▼
[Select review to respond to]
  │
  ▼
[Click "Respond"]
  │
  ▼
[Response Editor Opens]
  ├── Pre-written templates available
  ├── AI-suggested response (premium)
  └── Manual composition
  │
  ▼
[Preview Response]
  │
  ▼
[Submit Response]
  │
  ▼
[System posts to original platform via API]
  │
  ▼
[Log response in database]
  │
  ▼
[Update response time metrics]
```

---

## 5. Communication Hub Flow

### 5.1 Unified Inbox Flow

```
[User opens Inbox]
  │
  ▼
[System loads all conversations]
  ├── SMS conversations
  ├── Email threads
  ├── Social media messages
  └── Internal notes
  │
  ▼
[Conversations sorted by recent activity]
  │
  ▼
[User selects conversation]
  │
  ▼
[Full conversation history displayed]
  ├── Timeline view
  ├── Customer profile sidebar
  └── Quick actions panel
  │
  ▼
[User composes reply]
  │
  ▼
[Select channel (SMS/Email)]
  │
  ▼
[Compose message]
  ├── Use templates
  ├── Insert variables
  └── Attach files/media
  │
  ▼
[Send Message]
  │
  ▼
[System delivers via appropriate provider]
  │
  ▼
[Message logged to conversation timeline]
  │
  ▼
[Customer profile updated with interaction]
```

### 5.2 Two-Way SMS Booking Flow

```
[Customer receives appointment availability SMS]
  │
  ▼
[Customer replies with preferred time]
  │
  ▼
[System processes reply via Twilio webhook]
  │
  ▼
[NLP parses requested time]
  │
  ▼
[Check calendar availability]
  │
  ├─→ [TIME AVAILABLE] → [Confirm appointment]
  │                       └── Send confirmation SMS
  │                       └── Add to calendar
  │                       └── Create reminder workflow
  │
  └─→ [TIME UNAVAILABLE] → [Suggest alternatives]
                            └── Send alternative times SMS
```

---

## 6. Analytics & Reporting Flow

### 6.1 Dashboard View Flow

```
[User logs in]
  │
  ▼
[Dashboard loads with real-time metrics]
  ├── Today's leads count
  ├── Conversion rate (today/week/month)
  ├── Active workflows
  ├── Recent reviews
  ├── Team activity feed
  └── Revenue attribution chart
  │
  ▼
[User can filter by date range]
  │
  ▼
[User can drill down into specific metrics]
  │
  └─→ [Click on metric] → [Detailed report page]
```

### 6.2 Report Generation Flow

```
[User: Admin/Manager]
  │
  ▼
[Dashboard] → [Analytics] → [Reports]
  │
  ▼
[Select Report Type]
  ├── Lead Performance Report
  ├── Campaign Performance Report
  ├── Review Analytics Report
  ├── Team Performance Report
  └── Revenue Attribution Report
  │
  ▼
[Configure Parameters]
  ├── Date Range
  ├── Location (if multi-location)
  ├── Team Member Filter
  └── Lead Source Filter
  │
  ▼
[Generate Report]
  │
  ▼
[System queries data warehouse]
  │
  ▼
[Report renders with charts and tables]
  │
  ▼
[User Actions]
  ├── Export as PDF
  ├── Export as CSV
  ├── Schedule recurring delivery
  └── Share with team members
```

---

## 7. Subscription & Billing Flow

### 7.1 Initial Subscription Flow

```
[User completes onboarding]
  │
  ▼
[Select Pricing Tier]
  ├── Starter ($49/mo)
  ├── Professional ($149/mo)
  └── Business ($299/mo)
  │
  ▼
[Enter Payment Information]
  ├── Credit Card (Stripe Elements)
  └── Billing Address
  │
  ▼
[Review Subscription Details]
  ├── Plan features
  ├── Billing cycle
  └── Total amount
  │
  ▼
[Confirm Subscription]
  │
  ▼
[Stripe processes payment]
  │
  ├─→ [SUCCESS] → [Activate account]
  │                └── Set subscription status = active
  │                └── Create invoice record
  │                └── Send confirmation email
  │
  └─→ [FAILURE] → [Show error message]
                  └── Request alternative payment method
```

### 7.2 Subscription Upgrade/Downgrade Flow

```
[User: Admin]
  │
  ▼
[Settings] → [Billing] → [Change Plan]
  │
  ▼
[Select New Plan]
  │
  ▼
[System calculates prorated amount]
  │
  ▼
[Display pricing summary]
  │
  ▼
[Confirm Change]
  │
  ▼
[Stripe processes adjustment]
  │
  ▼
[Update subscription in database]
  │
  ▼
[Apply new feature limits immediately]
  │
  ▼
[Send confirmation email]
```

### 7.3 Failed Payment Recovery Flow

```
[Stripe webhook: payment.failed]
  │
  ▼
[System marks subscription as "past_due"]
  │
  ▼
[Send dunning email to admin]
  │
  ▼
[Retry payment after 3 days] (Stripe automatic)
  │
  ├─→ [SUCCESS] → [Restore active status]
  │
  └─→ [FAILURE after 3 attempts] → [Suspend account]
                                      └── Notify user
                                      └── Restrict access (read-only)
                                      └── Provide reactivation link
```

---

## 8. Mobile App Flow (Future Phase)

### 8.1 Mobile Login & Sync Flow

```
[User opens mobile app]
  │
  ▼
[Enter credentials / Biometric auth]
  │
  ▼
[Authenticate with backend]
  │
  ▼
[Sync recent data]
  ├── Today's appointments
  ├── Unread messages
  ├── New leads
  └── Pending tasks
  │
  ▼
[Display mobile dashboard]
  │
  ▼
[Push notifications enabled for:]
  ├── New leads
  ├── Negative reviews
  ├── Missed calls/messages
  └── Appointment reminders
```

---

## 9. Error Handling & Edge Cases

### 9.1 Common Error Flows

**Duplicate Lead Detection:**
```
[Lead creation attempt]
  │
  ▼
[Check existing records]
  │
  ├─→ [DUPLICATE] → [Show warning to user]
  │                  └── Display existing lead info
  │                  └── Offer to merge or create anyway
  │
  └─→ [UNIQUE] → [Proceed with creation]
```

**API Rate Limit Exceeded:**
```
[External API call fails with 429]
  │
  ▼
[System implements exponential backoff]
  │
  ▼
[Queue request for retry]
  │
  ▼
[Retry after delay]
  │
  ├─→ [SUCCESS] → [Continue normal flow]
  │
  └─→ [REPEATED FAILURE] → [Alert admin]
                            └── Log incident
                            └── Fallback to cached data if available
```

**User Permission Denied:**
```
[User attempts restricted action]
  │
  ▼
[System checks role permissions]
  │
  ▼
[ACCESS DENIED]
  │
  ▼
[Show friendly error message]
  │
  ▼
[Suggest contacting admin for access]
  │
  ▼
[Log unauthorized access attempt]
```

---

## 10. Key User Flow Metrics to Track

1. **Onboarding Completion Rate:** % who complete setup within 24 hours
2. **Time to First Value:** Time from signup to first lead captured
3. **Workflow Activation Rate:** % of users who create at least one automation
4. **Review Request Response Rate:** % of customers who leave reviews after request
5. **Message Response Time:** Average time for businesses to respond to inquiries
6. **Feature Adoption Funnel:** Progression through core features over time
7. **Churn Indicators:** Decreased activity patterns before cancellation

---

**Document Version:** 1.0  
**Last Updated:** [Current Date]  
**Author:** SaaS Architecture Team
