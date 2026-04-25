package com.smartfinance.data.local

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [
        LocalFinancialSetup::class,
        LocalPlan::class,
        LocalExpense::class,
        LocalSavingsProjectionCache::class,
        LocalComparativeInsightCache::class
    ],
    version = 2,
    exportSchema = false
)
abstract class SmartFinanceDatabase : RoomDatabase() {
    abstract fun smartFinanceDao(): SmartFinanceDao
}
