# Project Context Review

## Biggest Expense BQ Plan

- [x] Re-read spending insights ViewModel, Fragment, layout, strings, and expense/domain files.
- [x] Remove the biggest expense card from Home / plan insights.
- [x] Add a UI model/state for biggest expense this cycle in spending insights.
- [x] Compute biggest expense for the current cycle from user expenses and category total.
- [x] Render the new card in `fragment_spending_insights.xml`.
- [x] Run Android/Kotlin verification and document results.

## Expense Receipt Camera Feature Plan

- [x] Extend expense models/DTOs/local Room cache for one receipt image per expense.
- [x] Add Supabase Storage upload and `receipt_image_url` updates in the expense data layer.
- [x] Add camera/gallery picking and local cache copy to log expense.
- [x] Add receipt display/change flow to expense detail edit mode.
- [x] Pass receipt data through the expenses list/detail navigation.
- [x] Verify with Android build and document results.

## Plan

- [x] Map project architecture, modules, dependencies, and navigation.
- [x] Review Expenses feature end to end: views, viewmodels, domain, data, persistence, remote calls.
- [x] Review Insights features end to end: plan insights, spending insights, comparative insights, data flow and UI behavior.
- [x] Cross-check how Expenses data feeds or relates to Insights.
- [x] Run verification commands available for this Android/Kotlin project.
- [x] Document findings and open questions.

## Review

Completed May 22, 2026.

Architecture:
- Single Android module `:app` with Kotlin, Hilt, Navigation, ViewBinding, Supabase, Room, Coroutines, Serialization, DataStore, and Location Services.
- Package layering is `feature/*` for UI, `domain/*` for services/facades/VOs/DTOs, `data/*` for repositories/adapters/data sources/cache, and `core/*` for shared models, DI, network, and location.
- `MainActivity` hosts Navigation, wires bottom nav, hides it for auth/onboarding/log/detail screens, and switches start destination based on Supabase session and whether a generated plan exists.

Expenses:
- `MyExpensesFragment` lists expenses, reloads on resume, filters in memory, and opens detail/log screens.
- `MyExpensesViewModel` reads current user from Supabase Auth, calls `ExpenseApplicationService.getExpensesByUser`, sorts by `occurredAt`, maps to `ExpenseItemUiModel`, and applies search/category/current-month filters.
- `LogExpenseFragment` validates amount, note, category, date/time and saves through `LogExpenseViewModel`.
- `ExpenseApplicationService` validates and normalizes categories, notably `Bills -> utilities`.
- `SupabaseExpenseAdapter` inserts/selects/updates/deletes via `ExpenseRemoteDataSource`; create saves a Room copy, but list/update/delete do not use or maintain Room.
- `ExpenseDetailFragment` edits/deletes directly through `ExpenseApplicationService` without a ViewModel.

Insights:
- Bottom nav has two insight surfaces: `insightsFragment` for plan insights/home and `spendingInsightsFragment` for expense-based spending insights.
- Plan insights loads existing plan, savings projection, top categories, comparative insight, and location context.
- Savings projection and top categories flow through `PlanInsightsApplicationService -> PlanInsightsFacade -> BqRepositoryImpl -> PlanRemoteDataSource`, calling Supabase Functions `get-bq-savings-projection` and `get-bq-top-categories`, with memory and Room cache.
- Comparative insight is rendered inside plan insights, calls `get-bq-comparative-spending`, and caches in memory and Room.
- Spending insights calculates locally from remote expenses: current-month spend by category and days since last spend by category.

Expense/insight relationship:
- `spending_insights` directly depends on `ExpenseApplicationService.getExpensesByUser`.
- `plan_insights` and comparative insights depend indirectly on expenses through Supabase/BigQuery functions and only consume aggregates.
- After saving an expense, plan insights can refresh via the `expense_saved` saved-state key when returning to that screen.

Verification:
- `./gradlew assembleDebug` passed.
- No TypeScript type-checker or ESLint config applies to this Android/Kotlin project.

Notable risks:
- Room expense cache is incomplete and can become stale.
- Detail screen uses navigation arguments instead of reloading by id.
- Expense update/delete filter only by id and rely on backend/RLS for user isolation.
- Editing an expense date drops the original time.
- Detail amount parsing strips only `USD`, so non-USD currencies can parse as `0.0`.
- New expense currency is inferred from the first listed expense or defaults to `USD`, not from the user's financial setup.
- Create/edit category lists are inconsistent.

## Biggest Expense BQ Review

Completed May 22, 2026.

- Moved `Biggest expense this cycle` out of Home / `plan_insights`.
- Added the card to the bottom-nav Insights view / `spending_insights`.
- `SpendingInsightsViewModel` now reuses the current expense load, filters the current month cycle, chooses the largest expense, and calculates total spent in that expense category.
- The spending insights empty state now accounts for the new card.
- Verification: `./gradlew assembleDebug` passed.

## Expense Receipt Camera Feature Review

Completed May 22, 2026.

- Added optional one-photo receipt support for expenses through camera capture and gallery picking.
- Added `receipt_image_url` mapping to the Supabase expense model.
- Added Supabase Storage upload to bucket `expense-receipts`.
- Added Room cache fields for receipt URL, local URI, and sync status with database migration 4 to 5.
- Expense listing now caches remote expenses locally and falls back to Room if Supabase loading fails.
- Log expense saves selected receipt bytes on an IO dispatcher and stores local cache metadata.
- Expense detail shows the existing receipt and allows replacing it only in edit mode.
- Verification: `./gradlew assembleDebug` passed.

Backend requirements:
- Add nullable column `receipt_image_url` to the Supabase `expenses` table.
- Create/configure public bucket `expense-receipts` or adjust the app to use a private signed URL strategy.
