package com.smartfinance.data.insights

import com.smartfinance.domain.insights.ComparativeInsightVO
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ComparativeInsightMemoryCache @Inject constructor() {

    private var latestInsight: ComparativeInsightVO? = null

    fun getInsight(): ComparativeInsightVO? = latestInsight

    fun saveInsight(insight: ComparativeInsightVO) {
        latestInsight = insight
    }

    fun clear() {
        latestInsight = null
    }
}
