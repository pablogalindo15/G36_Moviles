package com.smartfinance.data.plan_insights



import com.smartfinance.domain.plan_insights.PlanSnapshotVO
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class PlanMemoryCache @Inject constructor() {

    private var latestSnapshot: PlanSnapshotVO? = null

    fun getSnapshot(): PlanSnapshotVO? = latestSnapshot

    fun saveSnapshot(snapshot: PlanSnapshotVO) {
        latestSnapshot = snapshot
    }

    fun clear() {
        latestSnapshot = null
    }
}