package com.smartfinance.data.local

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [
        LocalFinancialSetup::class,
        LocalPlan::class,
        LocalExpense::class,
        LocalSavingsProjectionCache::class,
        LocalComparativeInsightCache::class,
        LocalTopCategoriesCache::class
    ],
    version = 4,
    exportSchema = false
)
abstract class SmartFinanceDatabase : RoomDatabase() {
    abstract fun smartFinanceDao(): SmartFinanceDao
}
