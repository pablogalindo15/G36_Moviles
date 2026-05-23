# Lessons

- When the user says "vista de insights" in this project, map it to `spendingInsightsFragment` / `feature/spending_insights`, not the Home `insightsFragment` / `feature/plan_insights`.
- Before placing UI in a tab, confirm the destination through `bottom_nav_menu.xml` and `nav_graph.xml`; this project labels Home's fragment as `insightsFragment`, which is easy to confuse.
