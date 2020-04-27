

CREATE PROCEDURE [dbo].[procExtractWorkdayEFTSummaryFile]
    @RowsProcessed int output, 
    @Description  varchar(80) output
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON
    CREATE TABLE #tmpEFTSummaryData(
        WorkdayRegion INT
        ,EFTDate DATE
        ,TotalTransactionCount INT
        ,TotalTransactionAmount DECIMAL(26,6)
        ,ApprovedCount INT
        ,ApprovedAmount DECIMAL(26,6)
        ,ReturnedCount INT
        ,ReturnedAmount DECIMAL(26,6)
        ,TenderType VARCHAR(50)
        ,HeaderDateRange VARCHAR(4000)
        ,ReportRunDateTime DATETIME
        ,CurrencyCode VARCHAR(5)
        ,UniqueClubFlag VARCHAR(1)
        )

    DECLARE @sqlcmd AS VARCHAR(4000)
    DECLARE @StartDate as DATE = dateadd(dd,-1,getdate())
    DECLARE @EndDate as DATE = dateadd(dd,0,getdate())
    DECLARE @FolderPath as VARCHAR(100) = '\\ltfinc.net\ltfshare\Corp\Accounting\Integrations\WorkdayBankReconciliation\eftsummary\'
    DECLARE @FileName as VARCHAR(50) = 'MMSEFT_EXTRACT_' + CONVERT(varchar(8),getdate(), 112) + '_' + REPLACE(CONVERT(varchar(8),getdate(), 108),':','') + '.txt'

    INSERT #tmpEFTSummaryData (WorkdayRegion
        ,EFTDate
        ,TotalTransactionCount
        ,TotalTransactionAmount
        ,ApprovedCount
        ,ApprovedAmount
        ,ReturnedCount
        ,ReturnedAmount
        ,TenderType
        ,HeaderDateRange
        ,ReportRunDateTime
        ,CurrencyCode
        ,UniqueClubFlag)
    EXEC Report_MMS.dbo.procWorkday_EFTSummary @StartDate, @EndDate

    SELECT @RowsProcessed = COUNT(*) FROM #tmpEFTSummaryData
    SELECT @Description = 'Extract Workday EFT SummaryFile Total Rows'

    DROP TABLE #tmpEFTSummaryData

    SELECT @sqlcmd = 'SQLCMD -S SQLPRD-REPORT.LTFINC.NET -E -Q "EXEC Report_MMS.dbo.procWorkday_EFTSummary ''' + cast(@StartDate as varchar(15)) + ''', ''' + cast(@EndDate as varchar(15)) + '''" -s ^| -b -o ' + @FolderPath + @FileName
    
    EXECUTE AS LOGIN=N'LTFINC\PRDWSQL05srvc'
    EXEC master..xp_cmdshell @sqlcmd, no_output
    REVERT;
END

