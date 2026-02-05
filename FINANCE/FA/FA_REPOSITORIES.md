# FA Repository Patterns

**Purpose:** Standardized CTEs for Fixed Assets.

---

## 1. Asset Master (Complete with Depreciation)
*Complete asset register with depreciation details.*

```sql
FA_ASSET_MASTER_FULL AS (
    SELECT /*+ qb_name(FA_MST_FULL) MATERIALIZE */
           -- Asset Identification
           FAB.ASSET_ID
          ,FAB.ASSET_NUMBER
          ,FAT.DESCRIPTION ASSET_DESCRIPTION
          ,FAB.TAG_NUMBER
          ,FAB.ASSET_TYPE
          ,FAB.PARENT_ASSET_ID
          -- Category Details
          ,FCT.DESCRIPTION CATEGORY_DESCRIPTION
          ,FC.SEGMENT1 CATEGORY_MAJOR
          ,FC.SEGMENT2 CATEGORY_MINOR
          -- Book Details
          ,FB.BOOK_TYPE_CODE
          ,FB.COST ASSET_COST
          ,FB.ORIGINAL_COST
          ,FB.DATE_PLACED_IN_SERVICE
          ,FB.DATE_EFFECTIVE
          ,FB.DEPRN_START_DATE
          ,FB.LIFE_IN_MONTHS
          ,FB.RATE_ADJUSTMENT_FACTOR
          ,FB.RECOVERABLE_COST
          ,FB.SALVAGE_VALUE
          -- Depreciation Method
          ,FM.NAME DEPRECIATION_METHOD
          ,FM.RATE DEPRECIATION_RATE
          -- Depreciation Summary (Current Period)
          ,FDS.DEPRN_RESERVE ACCUMULATED_DEPRECIATION
          ,FDS.YTD_DEPRN YEAR_TO_DATE_DEPRECIATION
          ,FDS.PERIOD_NAME
          ,FB.COST - NVL(FDS.DEPRN_RESERVE, 0) NET_BOOK_VALUE
          -- Status
          ,CASE 
             WHEN FB.TRANSACTION_HEADER_ID_OUT IS NULL THEN 'Active'
             ELSE 'Historical'
           END ASSET_STATUS
    FROM   FA_ADDITIONS_B FAB
          ,FA_ADDITIONS_TL FAT
          ,FA_BOOKS FB
          ,FA_CATEGORIES_B FC
          ,FA_CATEGORIES_TL FCT
          ,FA_METHODS FM
          ,FA_DEPRN_SUMMARY FDS
    WHERE  FAB.ASSET_ID = FAT.ASSET_ID
      AND  FAT.LANGUAGE = USERENV('LANG')
      AND  FAB.ASSET_ID = FB.ASSET_ID
      AND  FAB.ASSET_CATEGORY_ID = FC.CATEGORY_ID
      AND  FC.CATEGORY_ID = FCT.CATEGORY_ID
      AND  FCT.LANGUAGE = USERENV('LANG')
      AND  FB.DEPRN_METHOD_CODE = FM.METHOD_ID(+)
      AND  FB.ASSET_ID = FDS.ASSET_ID(+)
      AND  FB.BOOK_TYPE_CODE = FDS.BOOK_TYPE_CODE(+)
      AND  FDS.PERIOD_COUNTER(+) = (SELECT MAX(FDS2.PERIOD_COUNTER)
                                     FROM   FA_DEPRN_SUMMARY FDS2
                                     WHERE  FDS2.ASSET_ID = FB.ASSET_ID
                                       AND  FDS2.BOOK_TYPE_CODE = FB.BOOK_TYPE_CODE)
      AND  FB.BOOK_TYPE_CODE = :P_BOOK
      AND  FB.TRANSACTION_HEADER_ID_OUT IS NULL
)
```

---

## 2. Asset Distribution (with Location and Employee)
*Asset assignment to location and employee with GL accounts.*

```sql
FA_ASSET_DIST AS (
    SELECT /*+ qb_name(FA_DIST) MATERIALIZE */
           FD.ASSET_ID
          ,FD.DISTRIBUTION_ID
          ,FD.BOOK_TYPE_CODE
          ,FD.UNITS_ASSIGNED
          ,FD.DATE_EFFECTIVE
          ,FD.DATE_INEFFECTIVE
          -- Location Details
          ,FL.LOCATION_ID
          ,FL.SEGMENT1 LOCATION_CODE
          ,FL.DESCRIPTION LOCATION_DESCRIPTION
          -- Employee Assignment
          ,PPNF.PERSON_ID EMPLOYEE_ID
          ,PPNF.DISPLAY_NAME EMPLOYEE_NAME
          -- GL Account Details
          ,GCCK_ASSET.CONCATENATED_SEGMENTS ASSET_ACCOUNT
          ,GCCK_DEPRN.CONCATENATED_SEGMENTS DEPRN_ACCOUNT
          ,GCCK_EXP.CONCATENATED_SEGMENTS EXPENSE_ACCOUNT
          -- Distribution Percentage
          ,(FD.UNITS_ASSIGNED / NULLIF(
               (SELECT SUM(FD2.UNITS_ASSIGNED)
                FROM   FA_DISTRIBUTION_HISTORY FD2
                WHERE  FD2.ASSET_ID = FD.ASSET_ID
                  AND  FD2.BOOK_TYPE_CODE = FD.BOOK_TYPE_CODE
                  AND  FD2.DATE_INEFFECTIVE IS NULL), 0)) * 100 DISTRIBUTION_PCT
    FROM   FA_DISTRIBUTION_HISTORY FD
          ,FA_LOCATIONS FL
          ,GL_CODE_COMBINATIONS_KFV GCCK_ASSET
          ,GL_CODE_COMBINATIONS_KFV GCCK_DEPRN
          ,GL_CODE_COMBINATIONS_KFV GCCK_EXP
          ,PER_PERSON_NAMES_F PPNF
    WHERE  FD.LOCATION_ID = FL.LOCATION_ID(+)
      AND  FD.CODE_COMBINATION_ID = GCCK_ASSET.CODE_COMBINATION_ID(+)
      AND  FD.DEPRN_RESERVE_CCID = GCCK_DEPRN.CODE_COMBINATION_ID(+)
      AND  FD.DEPRN_EXPENSE_CCID = GCCK_EXP.CODE_COMBINATION_ID(+)
      AND  FD.ASSIGNED_TO = PPNF.PERSON_ID(+)
      AND  PPNF.NAME_TYPE(+) = 'GLOBAL'
      AND  TRUNC(SYSDATE) BETWEEN TRUNC(PPNF.EFFECTIVE_START_DATE(+)) 
                              AND TRUNC(PPNF.EFFECTIVE_END_DATE(+))
      AND  FD.DATE_INEFFECTIVE IS NULL
      AND  FD.BOOK_TYPE_CODE = :P_BOOK
)
```

---

## 3. Depreciation Schedule
*Detailed depreciation tracking by period.*

```sql
FA_DEPRN_SCHEDULE AS (
    SELECT /*+ qb_name(FA_DEPRN_SCH) */
           FDS.ASSET_ID
          ,FDS.BOOK_TYPE_CODE
          ,FDS.PERIOD_NAME
          ,FDS.PERIOD_COUNTER
          ,FDS.FISCAL_YEAR
          -- Depreciation Amounts
          ,FDS.DEPRN_AMOUNT PERIOD_DEPRECIATION
          ,FDS.YTD_DEPRN YTD_DEPRECIATION
          ,FDS.DEPRN_RESERVE ACCUMULATED_DEPRECIATION
          -- Cost and NBV
          ,FDS.COST
          ,FDS.COST - FDS.DEPRN_RESERVE NET_BOOK_VALUE
          -- Adjustments
          ,FDS.ADJUSTMENT_AMOUNT
          ,FDS.BONUS_DEPRN_AMOUNT
          -- Period Details
          ,FDP.PERIOD_OPEN_DATE
          ,FDP.PERIOD_CLOSE_DATE
          ,FDP.DEPRECIATION_DATE
    FROM   FA_DEPRN_SUMMARY FDS
          ,FA_DEPRN_PERIODS FDP
    WHERE  FDS.BOOK_TYPE_CODE = FDP.BOOK_TYPE_CODE
      AND  FDS.PERIOD_COUNTER = FDP.PERIOD_COUNTER
      AND  FDS.BOOK_TYPE_CODE = :P_BOOK
      AND  FDS.PERIOD_NAME BETWEEN :P_FROM_PERIOD AND :P_TO_PERIOD
)
```

---

## 4. Asset Retirement Tracking
*Tracks retired/disposed assets.*

```sql
FA_RETIREMENT AS (
    SELECT /*+ qb_name(FA_RET) MATERIALIZE */
           FR.ASSET_ID
          ,FR.RETIREMENT_ID
          ,FR.DATE_RETIRED
          ,FR.DATE_EFFECTIVE
          ,FR.COST_RETIRED
          ,FR.NBV_RETIRED
          ,FR.PROCEEDS_OF_SALE
          ,FR.GAIN_LOSS_AMOUNT
          ,FR.COST_RETIRED - FR.NBV_RETIRED ACCUMULATED_DEPR_RETIRED
          ,FR.RETIREMENT_TYPE_CODE
          ,FR.STATUS
          ,CASE FR.STATUS
             WHEN 'PROCESSED' THEN 'Completed'
             WHEN 'PENDING' THEN 'Pending'
             WHEN 'DELETED' THEN 'Deleted'
             ELSE FR.STATUS
           END RETIREMENT_STATUS
          -- Asset Details
          ,FAB.ASSET_NUMBER
          ,FAT.DESCRIPTION
          ,FAB.TAG_NUMBER
    FROM   FA_RETIREMENTS FR
          ,FA_ADDITIONS_B FAB
          ,FA_ADDITIONS_TL FAT
    WHERE  FR.ASSET_ID = FAB.ASSET_ID
      AND  FAB.ASSET_ID = FAT.ASSET_ID
      AND  FAT.LANGUAGE = USERENV('LANG')
      AND  FR.BOOK_TYPE_CODE = :P_BOOK
      AND  FR.STATUS <> 'DELETED'
)
```

---

## 5. Asset Adjustment History
*Tracks cost and depreciation adjustments.*

```sql
FA_ADJUSTMENT_HISTORY AS (
    SELECT /*+ qb_name(FA_ADJ) */
           FA.ASSET_ID
          ,FA.ADJUSTMENT_ID
          ,FA.BOOK_TYPE_CODE
          ,FA.PERIOD_COUNTER_ADJUSTED
          ,FA.PERIOD_COUNTER_CREATED
          ,FA.ADJUSTMENT_TYPE
          ,FA.ADJUSTMENT_AMOUNT
          ,FA.DEBIT_CREDIT_FLAG
          ,CASE FA.DEBIT_CREDIT_FLAG
             WHEN 'DR' THEN FA.ADJUSTMENT_AMOUNT
             ELSE -FA.ADJUSTMENT_AMOUNT
           END NET_ADJUSTMENT
          ,FA.CODE_COMBINATION_ID
          ,GCCK.CONCATENATED_SEGMENTS GL_ACCOUNT
          -- Source Details
          ,FA.SOURCE_TYPE_CODE
          ,FA.SOURCE_LINE_ID
          -- Transaction Details
          ,FT.TRANSACTION_TYPE_CODE
          ,FT.TRANSACTION_DATE_ENTERED
          ,FT.TRANSACTION_NAME
    FROM   FA_ADJUSTMENTS FA
          ,GL_CODE_COMBINATIONS_KFV GCCK
          ,FA_TRANSACTION_HEADERS FT
    WHERE  FA.CODE_COMBINATION_ID = GCCK.CODE_COMBINATION_ID(+)
      AND  FA.TRANSACTION_HEADER_ID = FT.TRANSACTION_HEADER_ID(+)
      AND  FA.BOOK_TYPE_CODE = :P_BOOK
)
```
