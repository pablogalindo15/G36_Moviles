package com.smartfinance.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface SmartFinanceDao {

    // Financial Setup
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun saveFinancialSetup(setup: LocalFinancialSetup)

    @Query("SELECT * FROM local_financial_setup WHERE userId = :userId LIMIT 1")
    fun getFinancialSetup(userId: String): Flow<LocalFinancialSetup?>

    // Plan
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun savePlan(plan: LocalPlan)

    @Query("SELECT * FROM local_plan WHERE userId = :userId ORDER BY generatedAt DESC LIMIT 1")
    fun getLatestPlan(userId: String): Flow<LocalPlan?>

    // Expenses
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun saveExpense(expense: LocalExpense)

    @Query("SELECT * FROM local_expense WHERE userId = :userId ORDER BY date DESC")
    fun getExpenses(userId: String): Flow<List<LocalExpense>>

    @Query("DELETE FROM local_expense WHERE id = :expenseId")
    suspend fun deleteExpense(expenseId: String)

    // Clear data
    @Query("DELETE FROM local_financial_setup WHERE userId = :userId")
    suspend fun clearFinancialSetup(userId: String)

    @Query("DELETE FROM local_plan WHERE userId = :userId")
    suspend fun clearPlans(userId: String)

    @Query("DELETE FROM local_expense WHERE userId = :userId")
    suspend fun clearExpenses(userId: String)
}
