# Local Growth OS - Folder Structure

## Overview

This document defines the complete folder structure for Local Growth OS, organized by application layer and following modern SaaS best practices for maintainability, scalability, and team collaboration.

---

## 1. Repository Structure (Monorepo)

```
local-growth-os/
├── README.md
├── LICENSE
├── .gitignore
├── .editorconfig
├── .eslintrc.js
├── .prettierrc
├── turbo.json                    # Turborepo configuration
├── package.json                  # Root package.json
├── pnpm-workspace.yaml           # PNPM workspace config
├── docker-compose.yml            # Local development services
├── docker-compose.prod.yml       # Production services
├── Makefile                      # Common commands
│
├── apps/                         # Application code
│   ├── web/                      # Next.js web application
│   ├── mobile/                   # React Native mobile app
│   └── api/                      # API layer (if needed beyond Supabase)
│
├── packages/                     # Shared packages
│   ├── ui/                       # Shared UI components
│   ├── utils/                    # Shared utilities
│   ├── types/                    # TypeScript types
│   ├── config/                   # Shared configurations
│   └── workflows-engine/         # Workflow execution engine
│
├── supabase/                     # Supabase configuration
│   ├── migrations/               # Database migrations
│   ├── functions/                # Edge Functions
│   ├── seeds/                    # Seed data
│   ├── config.toml               # Supabase config
│   └── storage/                  # Storage policies
│
├── docs/                         # Documentation
│   ├── architecture/             # Architecture docs
│   ├── api/                      # API documentation
│   ├── user-guides/              # User documentation
│   └── runbooks/                 # Operational runbooks
│
├── scripts/                      # Utility scripts
│   ├── setup.sh                  # Initial setup
│   ├── seed-data.ts              # Seed database
│   ├── backup.sh                 # Backup scripts
│   └── deploy/                   # Deployment scripts
│
├── tests/                        # E2E and integration tests
│   ├── e2e/                      # End-to-end tests
│   ├── integration/              # Integration tests
│   └── fixtures/                 # Test fixtures
│
└── infrastructure/               # Infrastructure as Code
    ├── terraform/                # Terraform configurations
    ├── kubernetes/               # K8s manifests (if needed)
    └── pulumi/                   # Pulumi configurations
```

---

## 2. Web Application Structure

```
apps/web/
├── README.md
├── next.config.js
├── next-sitemap.config.js
├── tailwind.config.js
├── postcss.config.js
├── tsconfig.json
├── package.json
├── vitest.config.ts
├── playwright.config.ts
│
├── public/                       # Static assets
│   ├── favicon.ico
│   ├── apple-touch-icon.png
│   ├── logo.svg
│   ├── images/
│   │   ├── onboarding/
│   │   ├── illustrations/
│   │   └── backgrounds/
│   └── fonts/
│       └── inter/
│
├── src/
│   ├── app/                      # Next.js 14 App Router
│   │   ├── layout.tsx            # Root layout
│   │   ├── page.tsx              # Landing page
│   │   ├── global-error.tsx      # Error boundary
│   │   ├── robots.ts             # Robots.txt
│   │   ├── sitemap.ts            # Sitemap
│   │   │
│   │   ├── (auth)/               # Auth routes (grouped)
│   │   │   ├── layout.tsx        # Auth layout (centered)
│   │   │   ├── sign-in/
│   │   │   │   └── page.tsx
│   │   │   ├── sign-up/
│   │   │   │   └── page.tsx
│   │   │   ├── forgot-password/
│   │   │   │   └── page.tsx
│   │   │   └── reset-password/
│   │   │       └── page.tsx
│   │   │
│   │   ├── (dashboard)/          # Dashboard routes (with sidebar)
│   │   │   ├── layout.tsx        # Dashboard layout
│   │   │   ├── page.tsx          # Dashboard home
│   │   │   │
│   │   │   ├── leads/
│   │   │   │   ├── page.tsx      # Leads list
│   │   │   │   ├── [id]/
│   │   │   │   │   └── page.tsx  # Lead detail
│   │   │   │   └── new/
│   │   │   │       └── page.tsx  # New lead form
│   │   │   │
│   │   │   ├── pipeline/
│   │   │   │   └── page.tsx      # Pipeline board
│   │   │   │
│   │   │   ├── conversations/
│   │   │   │   ├── page.tsx      # Inbox
│   │   │   │   └── [id]/
│   │   │   │       └── page.tsx  # Conversation detail
│   │   │   │
│   │   │   ├── automation/
│   │   │   │   ├── page.tsx      # Workflows list
│   │   │   │   ├── [id]/
│   │   │   │   │   └── page.tsx  # Workflow editor
│   │   │   │   └── templates/
│   │   │   │       └── page.tsx  # Template library
│   │   │   │
│   │   │   ├── reviews/
│   │   │   │   ├── page.tsx      # Reviews dashboard
│   │   │   │   ├── requests/
│   │   │   │   │   └── page.tsx  # Review requests
│   │   │   │   └── platforms/
│   │   │   │       └── page.tsx  # Connected platforms
│   │   │   │
│   │   │   ├── campaigns/
│   │   │   │   ├── page.tsx      # Campaigns list
│   │   │   │   ├── new/
│   │   │   │   │   └── page.tsx  # Create campaign
│   │   │   │   └── [id]/
│   │   │   │       └── page.tsx  # Campaign analytics
│   │   │   │
│   │   │   ├── appointments/
│   │   │   │   ├── page.tsx      # Calendar view
│   │   │   │   └── [id]/
│   │   │   │       └── page.tsx  # Appointment detail
│   │   │   │
│   │   │   ├── analytics/
│   │   │   │   ├── page.tsx      # Analytics dashboard
│   │   │   │   ├── reports/
│   │   │   │   │   └── page.tsx  # Reports library
│   │   │   │   └── custom/
│   │   │   │       └── page.tsx  # Custom report builder
│   │   │   │
│   │   │   └── settings/
│   │   │       ├── page.tsx      # General settings
│   │   │       ├── team/
│   │   │       │   └── page.tsx  # Team management
│   │   │       ├── billing/
│   │   │       │   └── page.tsx  # Billing & subscription
│   │   │       ├── integrations/
│   │   │       │   └── page.tsx  # Integrations
│   │   │       ├── api-keys/
│   │   │       │   └── page.tsx  # API keys
│   │   │       └── data/
│   │   │           └── page.tsx  # Data export/import
│   │   │
│   │   ├── (marketing)/          # Marketing pages
│   │   │   ├── features/
│   │   │   │   └── page.tsx
│   │   │   ├── pricing/
│   │   │   │   └── page.tsx
│   │   │   ├── templates/
│   │   │   │   └── page.tsx
│   │   │   └── contact/
│   │   │       └── page.tsx
│   │   │
│   │   └── api/                  # API routes (if needed)
│   │       ├── webhooks/
│   │       │   ├── stripe/
│   │       │   │   └── route.ts
│   │       │   ├── twilio/
│   │       │   │   └── route.ts
│   │       │   └── facebook/
│   │       │       └── route.ts
│   │       └── internal/
│   │           └── health/
│   │               └── route.ts
│   │
│   ├── components/               # React components
│   │   ├── ui/                   # Base UI components (from packages/ui)
│   │   │   ├── button.tsx
│   │   │   ├── input.tsx
│   │   │   ├── dialog.tsx
│   │   │   ├── table.tsx
│   │   │   └── ...
│   │   │
│   │   ├── common/               # Common app components
│   │   │   ├── header.tsx
│   │   │   ├── sidebar.tsx
│   │   │   ├── footer.tsx
│   │   │   ├── search-command.tsx
│   │   │   ├── notifications.tsx
│   │   │   └── date-picker.tsx
│   │   │
│   │   ├── auth/                 # Auth-related components
│   │   │   ├── sign-in-form.tsx
│   │   │   ├── sign-up-form.tsx
│   │   │   ├── forgot-password-form.tsx
│   │   │   └── mfa-form.tsx
│   │   │
│   │   ├── leads/                # Lead-specific components
│   │   │   ├── lead-list.tsx
│   │   │   ├── lead-card.tsx
│   │   │   ├── lead-form.tsx
│   │   │   ├── lead-detail.tsx
│   │   │   ├── lead-activity-timeline.tsx
│   │   │   ├── lead-assign-dropdown.tsx
│   │   │   └── lead-import-modal.tsx
│   │   │
│   │   ├── pipeline/             # Pipeline components
│   │   │   ├── pipeline-board.tsx
│   │   │   ├── pipeline-column.tsx
│   │   │   ├── pipeline-card.tsx
│   │   │   ├── stage-edit-dialog.tsx
│   │   │   └── deal-form.tsx
│   │   │
│   │   ├── conversations/        # Conversation components
│   │   │   ├── inbox.tsx
│   │   │   ├── conversation-list.tsx
│   │   │   ├── conversation-item.tsx
│   │   │   ├── message-thread.tsx
│   │   │   ├── message-input.tsx
│   │   │   ├── message-bubble.tsx
│   │   │   └── conversation-details.tsx
│   │   │
│   │   ├── automation/           # Automation components
│   │   │   ├── workflow-list.tsx
│   │   │   ├── workflow-editor.tsx
│   │   │   ├── workflow-canvas.tsx
│   │   │   ├── workflow-node.tsx
│   │   │   ├── trigger-config.tsx
│   │   │   ├── action-config.tsx
│   │   │   └── template-card.tsx
│   │   │
│   │   ├── reviews/              # Review components
│   │   │   ├── review-dashboard.tsx
│   │   │   ├── review-list.tsx
│   │   │   ├── review-card.tsx
│   │   │   ├── review-response-form.tsx
│   │   │   ├── request-builder.tsx
│   │   │   └── platform-connect.tsx
│   │   │
│   │   ├── campaigns/            # Campaign components
│   │   │   ├── campaign-list.tsx
│   │   │   ├── campaign-builder.tsx
│   │   │   ├── audience-selector.tsx
│   │   │   ├── message-editor.tsx
│   │   │   ├── schedule-picker.tsx
│   │   │   └── campaign-stats.tsx
│   │   │
│   │   ├── analytics/            # Analytics components
│   │   │   ├── metrics-grid.tsx
│   │   │   ├── conversion-funnel.tsx
│   │   │   ├── revenue-chart.tsx
│   │   │   ├── activity-heatmap.tsx
│   │   │   ├── report-table.tsx
│   │   │   └── export-dropdown.tsx
│   │   │
│   │   └── settings/             # Settings components
│   │       ├── profile-form.tsx
│   │       ├── team-invite-form.tsx
│   │       ├── team-members-list.tsx
│   │       ├── role-permissions.tsx
│   │       ├── billing-plans.tsx
│   │       ├── invoice-list.tsx
│   │       └── integration-card.tsx
│   │
│   ├── lib/                      # Utilities and helpers
│   │   ├── supabase/
│   │   │   ├── client.ts         # Supabase client config
│   │   │   ├── server.ts         # Server-side client
│   │   │   ├── middleware.ts     # Middleware client
│   │   │   └── queries.ts        # Reusable queries
│   │   │
│   │   ├── api/
│   │   │   ├── client.ts         # API client
│   │   │   ├── handlers.ts       # Request handlers
│   │   │   └── errors.ts         # Error handling
│   │   │
│   │   ├── utils/
│   │   │   ├── cn.ts             # Class name utility
│   │   │   ├── formatters.ts     # Date, number, currency formatters
│   │   │   ├── validators.ts     # Zod schemas
│   │   │   ├── constants.ts      # App constants
│   │   │   └── helpers.ts        # General helpers
│   │   │
│   │   ├── hooks/
│   │   │   ├── use-auth.ts       # Auth state hook
│   │   │   ├── use-user.ts       # Current user hook
│   │   │   ├── use-tenant.ts     # Tenant context hook
│   │   │   ├── use-leads.ts      # Leads data hook
│   │   │   ├── use-conversations.ts
│   │   │   ├── use-workflows.ts
│   │   │   ├── use-realtime.ts   # Realtime subscription hook
│   │   │   └── use-media-query.ts
│   │   │
│   │   └── validations/
│   │       ├── auth.ts           # Auth validation schemas
│   │       ├── leads.ts          # Lead validation schemas
│   │       ├── workflows.ts      # Workflow validation
│   │       └── settings.ts       # Settings validation
│   │
│   ├── stores/                   # State management (Zustand)
│   │   ├── auth-store.ts         # Auth state
│   │   ├── tenant-store.ts       # Tenant state
│   │   ├── ui-store.ts           # UI state (modals, sidebar)
│   │   └── workflow-store.ts     # Workflow editor state
│   │
│   ├── contexts/                 # React contexts
│   │   ├── tenant-context.tsx    # Tenant provider
│   │   ├── feature-flag-context.tsx
│   │   └── realtime-context.tsx
│   │
│   ├── middleware.ts             # Next.js middleware (auth, tenant)
│   │
│   ├── types/                    # Local type definitions
│   │   ├── leads.ts
│   │   ├── conversations.ts
│   │   ├── workflows.ts
│   │   └── api.ts
│   │
│   └── styles/
│       ├── globals.css           # Global styles
│       ├── variables.css         # CSS variables
│       └── print.css             # Print styles
│
├── tests/
│   ├── unit/
│   │   ├── components/
│   │   ├── lib/
│   │   └── hooks/
│   ├── integration/
│   │   ├── auth.test.ts
│   │   ├── leads.test.ts
│   │   └── workflows.test.ts
│   └── e2e/
│       ├── onboarding.spec.ts
│       ├── lead-management.spec.ts
│       └── automation.spec.ts
│
└── CHANGELOG.md
```

---

## 3. Mobile App Structure

```
apps/mobile/
├── README.md
├── package.json
├── app.json                      # Expo/RN config
├── babel.config.js
├── metro.config.js
├── tsconfig.json
├── eas.json                      # EAS Build config
│
├── src/
│   ├── app/                      # Expo Router
│   │   ├── _layout.tsx           # Root layout
│   │   ├── index.tsx             # Home/Dashboard
│   │   ├── sign-in.tsx
│   │   │
│   │   ├── (tabs)/
│   │   │   ├── _layout.tsx       # Tab bar layout
│   │   │   ├── dashboard.tsx
│   │   │   ├── leads.tsx
│   │   │   ├── inbox.tsx
│   │   │   ├── calendar.tsx
│   │   │   └── settings.tsx
│   │   │
│   │   └── leads/
│   │       ├── [id].tsx          # Lead detail
│   │       └── new.tsx           # New lead form
│   │
│   ├── components/
│   │   ├── ui/                   # Mobile UI components
│   │   ├── leads/
│   │   ├── conversations/
│   │   └── common/
│   │
│   ├── lib/
│   │   ├── supabase/
│   │   ├── api/
│   │   ├── hooks/
│   │   └── utils/
│   │
│   ├── stores/
│   ├── types/
│   └── styles/
│
├── assets/
│   ├── images/
│   ├── fonts/
│   └── icons/
│
└── tests/
    ├── unit/
    └── e2e/
```

---

## 4. Supabase Structure

```
supabase/
├── config.toml                   # Supabase project config
├── .env                          # Environment variables (not committed)
├── .env.example                  # Example environment file
│
├── migrations/                   # Database migrations
│   ├── 0001_initial_schema.sql
│   ├── 0002_add_pipelines.sql
│   ├── 0003_add_workflows.sql
│   ├── 0004_add_reviews.sql
│   ├── 0005_add_appointments.sql
│   ├── 0006_add_campaigns.sql
│   ├── 0007_rls_policies.sql
│   ├── 0008_indexes_optimization.sql
│   └── ...
│
├── functions/                    # Edge Functions
│   ├── _shared/
│   │   ├── supabase-client.ts
│   │   ├── validators.ts
│   │   └── utils.ts
│   │
│   ├── webhooks/
│   │   ├── twilio-inbound/
│   │   │   ├── index.ts
│   │   │   └── deno.json
│   │   ├── stripe-webhook/
│   │   │   ├── index.ts
│   │   │   └── deno.json
│   │   ├── facebook-leads/
│   │   │   ├── index.ts
│   │   │   └── deno.json
│   │   └── google-reviews/
│   │       ├── index.ts
│   │       └── deno.json
│   │
│   ├── workflows/
│   │   ├── execute-workflow/
│   │   │   ├── index.ts
│   │   │   └── deno.json
│   │   ├── check-triggers/
│   │   │   ├── index.ts
│   │   │   └── deno.json
│   │   └── workflow-actions/
│   │       ├── send-sms.ts
│   │       ├── send-email.ts
│   │       └── update-status.ts
│   │
│   ├── integrations/
│   │   ├── sync-google-reviews/
│   │   │   ├── index.ts
│   │   │   └── deno.json
│   │   ├── sync-facebook-reviews/
│   │   │   ├── index.ts
│   │   │   └── deno.json
│   │   └── send-message/
│   │       ├── index.ts
│   │       └── deno.json
│   │
│   └── utils/
│       ├── aggregate-metrics/
│       │   ├── index.ts
│       │   └── deno.json
│       └── cleanup-old-data/
│           ├── index.ts
│           └── deno.json
│
├── seeds/                        # Seed data for development
│   ├── 00_tenants.sql
│   ├── 01_profiles.sql
│   ├── 02_contacts.sql
│   ├── 03_workflows.sql
│   └── 04_templates.sql
│
├── storage/
│   └── policies/
│       ├── tenant-assets.sql
│       ├── form-uploads.sql
│       └── email-attachments.sql
│
└── tests/
    ├── database/
    │   ├── rls_policies.test.ts
    │   └── functions.test.ts
    └── functions/
        ├── webhooks.test.ts
        └── workflows.test.ts
```

---

## 5. Packages Structure

### 5.1 UI Components Package

```
packages/ui/
├── package.json
├── tsconfig.json
├── tailwind.config.js
├── src/
│   ├── components/
│   │   ├── button/
│   │   │   ├── button.tsx
│   │   │   ├── button.stories.tsx
│   │   │   └── index.ts
│   │   ├── input/
│   │   ├── dialog/
│   │   ├── table/
│   │   ├── dropdown-menu/
│   │   ├── avatar/
│   │   ├── badge/
│   │   ├── card/
│   │   ├── skeleton/
│   │   ├── toast/
│   │   └── ...
│   │
│   ├── hooks/
│   │   └── use-toast.ts
│   │
│   ├── lib/
│   │   └── utils.ts
│   │
│   ├── styles/
│   │   └── globals.css
│   │
│   └── index.ts                # Barrel exports
│
└── CHANGELOG.md
```

### 5.2 Types Package

```
packages/types/
├── package.json
├── tsconfig.json
├── src/
│   ├── database.ts             # Database types from Supabase
│   ├── api.ts                  # API request/response types
│   ├── models/
│   │   ├── tenant.ts
│   │   ├── profile.ts
│   │   ├── contact.ts
│   │   ├── workflow.ts
│   │   ├── conversation.ts
│   │   └── ...
│   ├── events.ts               # Event types
│   └── index.ts                # Barrel exports
│
└── CHANGELOG.md
```

### 5.3 Workflows Engine Package

```
packages/workflows-engine/
├── package.json
├── tsconfig.json
├── src/
│   ├── engine/
│   │   ├── executor.ts         # Workflow execution logic
│   │   ├── scheduler.ts        # Trigger scheduling
│   │   ├── state-machine.ts    # Workflow state management
│   │   └── error-handler.ts    # Error handling & retries
│   │
│   ├── actions/
│   │   ├── send-sms.ts
│   │   ├── send-email.ts
│   │   ├── update-contact.ts
│   │   ├── create-task.ts
│   │   └── webhook.ts
│   │
│   ├── triggers/
│   │   ├── time-based.ts
│   │   ├── action-based.ts
│   │   └── webhook-based.ts
│   │
│   ├── nodes/
│   │   ├── action-node.ts
│   │   ├── condition-node.ts
│   │   ├── wait-node.ts
│   │   └── split-node.ts
│   │
│   ├── types/
│   │   └── workflow.ts
│   │
│   └── index.ts
│
├── tests/
│   ├── executor.test.ts
│   └── actions.test.ts
│
└── CHANGELOG.md
```

---

## 6. Infrastructure Structure

```
infrastructure/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   │
│   ├── environments/
│   │   ├── dev/
│   │   │   ├── main.tf
│   │   │   └── terraform.tfvars
│   │   ├── staging/
│   │   │   ├── main.tf
│   │   │   └── terraform.tfvars
│   │   └── production/
│   │       ├── main.tf
│   │       └── terraform.tfvars
│   │
│   ├── modules/
│   │   ├── vpc/
│   │   ├── database/
│   │   ├── cache/
│   │   └── monitoring/
│   │
│   └── scripts/
│       ├── init.sh
│       └── migrate.sh
│
├── kubernetes/                 # If using K8s
│   ├── base/
│   ├── overlays/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── production/
│   └── helm/
│
└── pulumi/                     # Alternative IaC
    ├── index.ts
    ├── package.json
    └── Pulumi.yaml
```

---

## 7. Documentation Structure

```
docs/
├── README.md
│
├── architecture/
│   ├── overview.md
│   ├── database-schema.md
│   ├── security-model.md
│   ├── scalability-plan.md
│   └── decisions/
│       ├── adr-001-supabase.md
│       ├── adr-002-nextjs.md
│       └── adr-003-monorepo.md
│
├── api/
│   ├── rest-api.md
│   ├── graphql-api.md (future)
│   ├── webhooks.md
│   └── openapi.yaml
│
├── user-guides/
│   ├── getting-started.md
│   ├── lead-management.md
│   ├── automation.md
│   ├── reviews.md
│   └── faq.md
│
├── runbooks/
│   ├── deployment.md
│   ├── incident-response.md
│   ├── backup-restore.md
│   ├── scaling-database.md
│   └── monitoring-alerts.md
│
├── development/
│   ├── setup-guide.md
│   ├── coding-standards.md
│   ├── testing-guide.md
│   └── contribution-guide.md
│
└── compliance/
    ├── gdpr.md
    ├── ccpa.md
    ├── tcpa.md
    └── soc2-checklist.md
```

---

## 8. Key Configuration Files

### 8.1 Root package.json

```json
{
  "name": "local-growth-os",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "dev": "turbo run dev",
    "build": "turbo run build",
    "lint": "turbo run lint",
    "test": "turbo run test",
    "typecheck": "turbo run typecheck",
    "db:migrate": "supabase db push",
    "db:seed": "tsx scripts/seed-data.ts",
    "functions:deploy": "supabase functions deploy",
    "clean": "turbo run clean && rm -rf node_modules"
  },
  "devDependencies": {
    "turbo": "^1.11.0",
    "typescript": "^5.3.0",
    "eslint": "^8.54.0",
    "prettier": "^3.1.0"
  },
  "packageManager": "pnpm@8.10.0",
  "engines": {
    "node": ">=18.0.0"
  }
}
```

### 8.2 turbo.json

```json
{
  "$schema": "https://turbo.build/schema.json",
  "globalDependencies": ["**/.env.*local"],
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "!.next/cache/**"]
    },
    "lint": {},
    "dev": {
      "cache": false,
      "persistent": true
    },
    "test": {
      "dependsOn": ["build"]
    },
    "typecheck": {}
  }
}
```

### 8.3 pnpm-workspace.yaml

```yaml
packages:
  - "apps/*"
  - "packages/*"
```

---

## 9. Naming Conventions

### Files & Folders
- **Components:** PascalCase (`LeadCard.tsx`)
- **Utilities:** camelCase (`formatters.ts`)
- **Hooks:** camelCase with prefix (`useAuth.ts`)
- **Types:** PascalCase (`Contact.ts`)
- **Tests:** Same name as source (`.test.ts` or `.spec.ts`)
- **Stories:** Same name as component (`.stories.tsx`)

### Code Style
- **Variables:** camelCase
- **Constants:** UPPER_SNAKE_CASE
- **Classes:** PascalCase
- **Database:** snake_case
- **URLs:** kebab-case

---

## 10. Development Workflow

### Local Development
```bash
# Clone repository
git clone git@github.com:local-growth-os.git
cd local-growth-os

# Install dependencies
pnpm install

# Set up environment
cp .env.example .env
# Edit .env with your values

# Start Supabase locally
supabase start

# Run migrations
pnpm db:migrate

# Seed database
pnpm db:seed

# Start development servers
pnpm dev
```

### Running Tests
```bash
# Unit tests
pnpm test

# E2E tests
pnpm test:e2e

# Specific test file
pnpm test leads.test.ts
```

### Deployment
```bash
# Deploy to staging
pnpm deploy:staging

# Deploy to production
pnpm deploy:production

# Deploy Edge Functions
pnpm functions:deploy
```

---

**Document Version:** 1.0  
**Last Updated:** [Current Date]  
**Author:** SaaS Architecture Team
