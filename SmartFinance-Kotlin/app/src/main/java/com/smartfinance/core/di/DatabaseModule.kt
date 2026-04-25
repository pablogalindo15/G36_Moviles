package com.smartfinance.core.di

import android.content.Context
import androidx.room.migration.Migration
import androidx.room.Room
import androidx.sqlite.db.SupportSQLiteDatabase
import com.smartfinance.data.local.SmartFinanceDao
import com.smartfinance.data.local.SmartFinanceDatabase
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    private val migration1To2 = object : Migration(1, 2) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE IF NOT EXISTS local_savings_projection (
                    userId TEXT NOT NULL,
                    isOnTrack INTEGER NOT NULL,
                    projectedSavings REAL NOT NULL,
                    savingsGoal REAL NOT NULL,
                    message TEXT NOT NULL,
                    computedAt INTEGER NOT NULL,
                    cachedAt INTEGER NOT NULL,
                    PRIMARY KEY(userId)
                )
                """.trimIndent()
            )
            db.execSQL(
                """
                CREATE TABLE IF NOT EXISTS local_comparative_insight (
                    userId TEXT NOT NULL,
                    type TEXT NOT NULL,
                    myWeeklySpending REAL,
                    cohortAverageWeeklySpending REAL,
                    cohortSize INTEGER NOT NULL,
                    percentile REAL,
                    currency TEXT,
                    weekStart TEXT,
                    weekEnd TEXT,
                    reason TEXT,
                    cachedAt INTEGER NOT NULL,
                    PRIMARY KEY(userId)
                )
                """.trimIndent()
            )
        }
    }

    private val migration2To3 = object : Migration(2, 3) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE IF NOT EXISTS local_expense_new (
                    id TEXT NOT NULL,
                    userId TEXT NOT NULL,
                    amount REAL NOT NULL,
                    currency TEXT NOT NULL,
                    category TEXT NOT NULL,
                    note TEXT,
                    occurredAt TEXT NOT NULL,
                    createdAt TEXT NOT NULL,
                    clientUuid TEXT NOT NULL,
                    PRIMARY KEY(id)
                )
                """.trimIndent()
            )
            db.execSQL(
                """
                INSERT INTO local_expense_new (
                    id,
                    userId,
                    amount,
                    currency,
                    category,
                    note,
                    occurredAt,
                    createdAt,
                    clientUuid
                )
                SELECT
                    id,
                    userId,
                    amount,
                    'USD',
                    category,
                    description,
                    date,
                    date,
                    id
                FROM local_expense
                """.trimIndent()
            )
            db.execSQL("DROP TABLE local_expense")
            db.execSQL("ALTER TABLE local_expense_new RENAME TO local_expense")
        }
    }

    private val migration3To4 = object : Migration(3, 4) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE IF NOT EXISTS local_top_categories (
                    userId TEXT NOT NULL,
                    totalExpenses INTEGER NOT NULL,
                    periodDays INTEGER NOT NULL,
                    topCategoriesJson TEXT NOT NULL,
                    reason TEXT,
                    cachedAt INTEGER NOT NULL,
                    PRIMARY KEY(userId)
                )
                """.trimIndent()
            )
        }
    }

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): SmartFinanceDatabase {
        return Room.databaseBuilder(
            context,
            SmartFinanceDatabase::class.java,
            "smart_finance_db"
        )
            .addMigrations(migration1To2)
            .addMigrations(migration2To3)
            .addMigrations(migration3To4)
            .build()
    }

    @Provides
    fun provideSmartFinanceDao(database: SmartFinanceDatabase): SmartFinanceDao {
        return database.smartFinanceDao()
    }
}
