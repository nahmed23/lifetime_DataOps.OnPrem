

/*******************************************************
 * This Procedure is used to find the differences between
 * the MMS_DB01 and MMS_Archive databases on the
 * MNDEVDB02 database server.
 *******************************************************/


CREATE PROCEDURE dbo.mmsValidateReplicationData(@DaysBack INT,@Message VARCHAR(2000) OUTPUT)
AS
BEGIN
  SET XACT_ABORT ON
  SET NOCOUNT ON 
	-- Find missing data from the EFT table
	DECLARE @Rowcount INT

	SET @Rowcount = 0
	SET @Message = ''

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY	 
	-----------------------------------------------
	--  Select data from the production database (MMS_DB01)
	SELECT *
	  INTO #EFTProd
	  FROM [MMS_DB01].[dbo].[EFT]
	 WHERE EFTDate < CONVERT(VARCHAR,DATEADD(d,@DaysBack,GETDATE()),110)
	 
	-----------------------------------------------
	-- Check for differences in the EFT table
	-- on the Production and Archive databases
	SELECT PROD.EFTID
	  INTO #EFTTemp
	  FROM #EFTProd PROD
	  LEFT JOIN [MMS_Archive].[dbo].EFT ARCH
	    ON PROD.EFTID = ARCH.EFTID
	   AND ISNULL(PROD.AccountOwner, 7) = ISNULL(ARCH.AccountOwner, 7)
	   AND ISNULL(PROD.EFTAmount, 7) = ISNULL(ARCH.EFTAmount, 7)
	   AND ISNULL(PROD.EFTDate, 7) = ISNULL(ARCH.EFTDate, 7)
	   AND ISNULL(PROD.EFTReturnCodeID, 7) = ISNULL(ARCH.EFTReturnCodeID, 7)
	   AND ISNULL(PROD.ExpirationDate, 7) = ISNULL(ARCH.ExpirationDate, 7)
	   AND ISNULL(PROD.MembershipID, 7) = ISNULL(ARCH.MembershipID, 7)
	   AND ISNULL(PROD.PaymentID, 7) = ISNULL(ARCH.PaymentID, 7)
	   AND ISNULL(PROD.ReturnCode, 7) = ISNULL(ARCH.ReturnCode, 7)
	   AND ISNULL(PROD.ValEFTStatusID, 7) = ISNULL(ARCH.ValEFTStatusID, 7)
	   AND ISNULL(PROD.ValEFTTypeID, 7) = ISNULL(ARCH.ValEFTTypeID, 7)
	   AND ISNULL(PROD.ValPaymentTypeID, 7) = ISNULL(ARCH.ValPaymentTypeID, 7)
	 WHERE ARCH.EFTID IS NULL
	 
	SELECT @Rowcount = COUNT(*) FROM #EFTTemp
	
	IF @Rowcount <> 0
	BEGIN
	  SET @Message = @Message + ' There are ' + CONVERT(VARCHAR, @Rowcount) + ' different records in EFT'
	END
	 
	-- Clean up temp tables
	DROP TABLE #EFTProd
	DROP TABLE #EFTTemp
	 
	------------------------------------------------------
	-- Find missing data from the MemberUsage table
	SET @Rowcount = 0
	 
	-----------------------------------------------
	--  Select data from the production database (MMS_DB01)
	SELECT *
	  INTO #MemberUsageProd
	  FROM [MMS_DB01].[dbo].[MemberUsage]
	 WHERE InsertedDateTime < CONVERT(VARCHAR,DATEADD(d,@DaysBack,GETDATE()),110)
	 
	 
	-----------------------------------------------
	-- Check for differences in the MemberUsage table
	-- on the Production and Archive databases
	SELECT PROD.MemberUsageID
	  INTO #MemberUsageTemp
	  FROM #MemberUsageProd PROD
	  LEFT JOIN [MMS_Archive].[dbo].MemberUsage ARCH
	    ON PROD.MemberUsageID = ARCH.MemberUsageID
	   AND ISNULL(PROD.ClubID, 7) = ISNULL(ARCH.ClubID, 7)
	   AND ISNULL(PROD.MemberID, 7) = ISNULL(ARCH.MemberID, 7)
	   AND ISNULL(PROD.UsageDateTime, 7) = ISNULL(ARCH.UsageDateTime, 7)
	   AND ISNULL(PROD.UsageDateTimeZone, 7) = ISNULL(ARCH.UsageDateTimeZone, 7)
	   AND ISNULL(PROD.UTCUsageDateTime, 7) = ISNULL(ARCH.UTCUsageDateTime, 7)
	 WHERE ARCH.MemberUsageID IS NULL
	 
	SELECT @Rowcount = COUNT(*) FROM #MemberUsageTemp
	 
	IF @Rowcount <> 0
	BEGIN
	  SET @Message = @Message + ' There are ' + CONVERT(VARCHAR, @Rowcount) + ' different records in MemberUsage'
	END
	 
	-----------------------------------------------
	-- Clean up temp tables
	DROP TABLE #MemberUsageProd
	DROP TABLE #MemberUsageTemp
	 
	------------------------------------------------------
	-- Find missing data from the MMSTran table
	SET @Rowcount = 0
	 
	-----------------------------------------------
	--  Select data from the production database (MMS_DB01)
	SELECT *
	  INTO #MMSTranProd
	  FROM [MMS_DB01].[dbo].[MMSTran]
	 WHERE InsertedDateTime < CONVERT(VARCHAR,DATEADD(d,@DaysBack,GETDATE()),110)
	 
	-----------------------------------------------
	-- Check for differences in the MMSTran table
	-- on the Production and Archive databases
	SELECT PROD.MMSTranID
	  INTO #MMSTranTemp
	  FROM #MMSTranProd PROD
	  LEFT JOIN [MMS_Archive].[dbo].MMSTran ARCH
	    ON PROD.MMSTranID = ARCH.MMSTranID
	   AND ISNULL(PROD.ChangeRendered, 7) = ISNULL(ARCH.ChangeRendered, 7)
	   AND ISNULL(PROD.ClubID, 7) = ISNULL(ARCH.ClubID, 7)
	   AND ISNULL(PROD.DomainName, 7) = ISNULL(ARCH.DomainName, 7)
	   AND ISNULL(PROD.DrawerActivityID, 7) = ISNULL(ARCH.DrawerActivityID, 7)
	   AND ISNULL(PROD.EmployeeID, 7) = ISNULL(ARCH.EmployeeID, 7)
	   AND ISNULL(PROD.MemberID, 7) = ISNULL(ARCH.MemberID, 7)
	   AND ISNULL(PROD.MembershipID, 7) = ISNULL(ARCH.MembershipID, 7)
	   AND ISNULL(PROD.OriginalDrawerActivityID, 7) = ISNULL(ARCH.OriginalDrawerActivityID, 7)
	   AND ISNULL(PROD.POSAmount, 7) = ISNULL(ARCH.POSAmount, 7)
	   AND ISNULL(PROD.PostDateTime, 7) = ISNULL(ARCH.PostDateTime, 7)
	   AND ISNULL(PROD.PostDateTimeZone, 7) = ISNULL(ARCH.PostDateTimeZone, 7)
	   AND ISNULL(PROD.ReasonCodeID, 7) = ISNULL(ARCH.ReasonCodeID, 7)
	   AND ISNULL(PROD.ReceiptComment, 7) = ISNULL(ARCH.ReceiptComment, 7)
	   AND ISNULL(PROD.ReceiptNumber, 7) = ISNULL(ARCH.ReceiptNumber, 7)
	   AND ISNULL(PROD.TranAmount, 7) = ISNULL(ARCH.TranAmount, 7)
	   AND ISNULL(PROD.TranDate, 7) = ISNULL(ARCH.TranDate, 7)
	   AND ISNULL(PROD.TranVoidedID, 7) = ISNULL(ARCH.TranVoidedID, 7)
	   AND ISNULL(PROD.UTCPostDateTime, 7) = ISNULL(ARCH.UTCPostDateTime, 7)
	   AND ISNULL(PROD.ValTranTypeID, 7) = ISNULL(ARCH.ValTranTypeID, 7)
	 WHERE ARCH.MMSTranID IS NULL
	 
	SELECT @Rowcount = COUNT(*) FROM #MMSTranTemp
	 
	IF @Rowcount <> 0
	BEGIN
	  SET @Message = @Message + ' There are ' + CONVERT(VARCHAR, @Rowcount) + ' different records in MMSTran'
	END
	 
	-----------------------------------------------
	-- Clean up temp tables
	DROP TABLE #MMSTranProd
	DROP TABLE #MMSTranTemp
	 
	------------------------------------------------------
	-- Find missing data from the Payment table
	SET @Rowcount = 0
	 
	-----------------------------------------------
	--  Select data from the production database (MMS_DB01)
	SELECT *
	  INTO #PaymentProd
	  FROM [MMS_DB01].[dbo].[Payment]
	 WHERE InsertedDateTime  < CONVERT(VARCHAR,DATEADD(d,@DaysBack,GETDATE()),110)
	 
	-----------------------------------------------
	-- Check for differences in the Payment table
	-- on the Production and Archive databases
	SELECT PROD.PaymentID
	  INTO #PaymentTemp
	  FROM #PaymentProd PROD
	  LEFT JOIN [MMS_Archive].[dbo].Payment ARCH
	    ON PROD.PaymentID = ARCH.PaymentID
	   AND ISNULL(PROD.ApprovalCode, 7) = ISNULL(ARCH.ApprovalCode, 7)
	   AND ISNULL(PROD.MMSTranID, 7) = ISNULL(ARCH.MMSTranID, 7)
	   AND ISNULL(PROD.PaymentAmount, 7) = ISNULL(ARCH.PaymentAmount, 7)
	   AND ISNULL(PROD.ValPaymentTypeID, 7) = ISNULL(ARCH.ValPaymentTypeID, 7)
	 WHERE ARCH.PaymentID IS NULL
	 
	 
	SELECT @Rowcount = COUNT(*) FROM #PaymentTemp
	 
	IF @Rowcount <> 0
	BEGIN
	  SET @Message = @Message + ' There are ' + CONVERT(VARCHAR, @Rowcount) + ' different records in Payment'
	END
	
	-----------------------------------------------
	-- Clean up temp tables
	DROP TABLE #PaymentProd
	DROP TABLE #PaymentTemp
	 
	------------------------------------------------------
	-- Find missing data from the PaymentAccount table
	SET @Rowcount = 0
	 
	-----------------------------------------------
	--  Select data from the production database (MMS_DB01)
	SELECT *
	  INTO #PaymentAccountProd
	  FROM [MMS_DB01].[dbo].[PaymentAccount]
	 WHERE InsertedDateTime < CONVERT(VARCHAR,DATEADD(d,@DaysBack,GETDATE()),110)
	 
	-----------------------------------------------
	-- Check for differences in the PaymentAccount table
	-- on the Production and Archive databases
	SELECT PROD.PaymentAccountID
	  INTO #PaymentAccountTemp
	  FROM #PaymentAccountProd PROD
	  LEFT JOIN [MMS_Archive].[dbo].PaymentAccount ARCH
	    ON PROD.PaymentAccountID = ARCH.PaymentAccountID
	   AND ISNULL(PROD.AccountNumber, 7) = ISNULL(ARCH.AccountNumber, 7)
	   AND ISNULL(PROD.BankName, 7) = ISNULL(ARCH.BankName, 7)
	   AND ISNULL(PROD.ExpirationDate, 7) = ISNULL(ARCH.ExpirationDate, 7)
	   AND ISNULL(PROD.Name, 7) = ISNULL(ARCH.Name, 7)
	   AND ISNULL(PROD.PaymentID, 7) = ISNULL(ARCH.PaymentID, 7)
	   AND ISNULL(PROD.RoutingNumber, 7) = ISNULL(ARCH.RoutingNumber, 7)
	 WHERE ARCH.PaymentAccountID IS NULL
	 
	SELECT @Rowcount = COUNT(*) FROM #PaymentAccountTemp
	 
	IF @Rowcount <> 0
	BEGIN
	  SET @Message = @Message + ' There are ' + CONVERT(VARCHAR, @Rowcount) + ' different records in PaymentAccount'
	END
	 
	-----------------------------------------------
	-- Clean up temp tables
	DROP TABLE #PaymentAccountProd
	DROP TABLE #PaymentAccountTemp
	 
	------------------------------------------------------
	-- Find missing data from the SaleCommission table
	SET @Rowcount = 0
	 
	-----------------------------------------------
	--  Select data from the production database (MMS_DB01)
	SELECT *
	  INTO #SaleCommissionProd
	  FROM [MMS_DB01].[dbo].[SaleCommission]
	 WHERE InsertedDateTime < CONVERT(VARCHAR,DATEADD(d,@DaysBack,GETDATE()),110)
	 
	-----------------------------------------------
	-- Check for differences in the SaleCommission table
	-- on the Production and Archive databases
	SELECT PROD.SaleCommissionID
	  INTO #SaleCommissionTemp
	  FROM #SaleCommissionProd PROD
	  LEFT JOIN [MMS_Archive].[dbo].SaleCommission ARCH
	    ON PROD.SaleCommissionID = ARCH.SaleCommissionID
	   AND ISNULL(PROD.EmployeeID, 7) = ISNULL(ARCH.EmployeeID, 7)
	   AND ISNULL(PROD.TranItemID, 7) = ISNULL(ARCH.TranItemID, 7)
	 WHERE ARCH.SaleCommissionID IS NULL
	 
	SELECT @Rowcount = COUNT(*) FROM #SaleCommissionTemp
	 
	IF @Rowcount <> 0
	BEGIN
	  SET @Message = @Message + ' There are ' + CONVERT(VARCHAR, @Rowcount) + ' different records in SaleCommission'
	END
	 
	-----------------------------------------------
	-- Clean up temp tables
	DROP TABLE #SaleCommissionProd
	DROP TABLE #SaleCommissionTemp
	 
	------------------------------------------------------
	-- Find missing data from the TranItem table
	SET @Rowcount = 0
	 
	-----------------------------------------------
	--  Select data from the production database (MMS_DB01)
	SELECT *
	  INTO #TranItemProd
	  FROM [MMS_DB01].[dbo].[TranItem]
	 WHERE InsertedDateTime < CONVERT(VARCHAR,DATEADD(d,@DaysBack,GETDATE()),110)
	 
	-----------------------------------------------
	-- Check for differences in the TranItem table
	-- on the Production and Archive databases
	SELECT PROD.TranItemID
	  INTO #TranItemTemp
	  FROM #TranItemProd PROD
	  LEFT JOIN [MMS_Archive].[dbo].TranItem ARCH
	    ON PROD.TranItemID = ARCH.TranItemID
	   AND ISNULL(PROD.ItemAmount, 7) = ISNULL(ARCH.ItemAmount, 7)
	   AND ISNULL(PROD.ItemSalesTax, 7) = ISNULL(ARCH.ItemSalesTax, 7)
	   AND ISNULL(PROD.MMSTranID, 7) = ISNULL(ARCH.MMSTranID, 7)
	   AND ISNULL(PROD.ProductID, 7) = ISNULL(ARCH.ProductID, 7)
	   AND ISNULL(PROD.Quantity, 7) = ISNULL(ARCH.Quantity, 7)
	 WHERE ARCH.TranItemID IS NULL
	 
	SELECT @Rowcount = COUNT(*) FROM #TranItemTemp
	 
	IF @Rowcount <> 0
	BEGIN
	  SET @Message = @Message + ' There are ' + CONVERT(VARCHAR, @Rowcount) + ' different records in TranItem'
	END
	 
	 
	-----------------------------------------------
	-- Clean up temp tables
	DROP TABLE #TranItemProd
	DROP TABLE #TranItemTemp
	 
	------------------------------------------------------
	-- Find missing data from the TranItemTax table
	SET @Rowcount = 0
	 
	-----------------------------------------------
	--  Select data from the production database (MMS_DB01)
	SELECT *
	  INTO #TranItemTaxProd
	  FROM [MMS_DB01].[dbo].[TranItemTax]
	 WHERE InsertedDateTime < CONVERT(VARCHAR,DATEADD(d,@DaysBack,GETDATE()),110)
	 
	-----------------------------------------------
	-- Check for differences in the TranItemTax table
	-- on the Production and Archive databases
	SELECT PROD.TranItemTaxID
	  INTO #TranItemTaxTemp
	  FROM #TranItemTaxProd PROD
	  LEFT JOIN [MMS_Archive].[dbo].TranItemTax ARCH
	    ON PROD.TranItemTaxID = ARCH.TranItemTaxID
	   AND ISNULL(PROD.ItemTaxAmount, 7) = ISNULL(ARCH.ItemTaxAmount, 7)
	   AND ISNULL(PROD.TaxPercentage, 7) = ISNULL(ARCH.TaxPercentage, 7)
	   AND ISNULL(PROD.TaxRateID, 7) = ISNULL(ARCH.TaxRateID, 7)
	   AND ISNULL(PROD.TranItemID, 7) = ISNULL(ARCH.TranItemID, 7)
	   AND ISNULL(PROD.ValTaxTypeID, 7) = ISNULL(ARCH.ValTaxTypeID, 7)
	 WHERE ARCH.TranItemTaxID IS NULL
	 
	SELECT @Rowcount = COUNT(*) FROM #TranItemTaxTemp
	 
	IF @Rowcount <> 0
	BEGIN
	  SET @Message = @Message + ' There are ' + CONVERT(VARCHAR, @Rowcount) + ' different records in TranItemTax'
	END
	 
	-----------------------------------------------
	-- Clean up temp tables
	DROP TABLE #TranItemTaxProd
	DROP TABLE #TranItemTaxTemp
	 
	------------------------------------------------------
	-- Find missing data from the TranVoided table
	SET @Rowcount = 0
	-----------------------------------------------
	--  Select data from the production database (MMS_DB01)
	SELECT *
	  INTO #TranVoidedProd
	  FROM [MMS_DB01].[dbo].[TranVoided]
	 WHERE InsertedDateTime < CONVERT(VARCHAR,DATEADD(d,@DaysBack,GETDATE()),110)
	 
	-----------------------------------------------
	-- Check for differences in the TranVoided table
	-- on the Production and Archive databases
	SELECT PROD.TranVoidedID
	  INTO #TranVoidedTemp
	  FROM #TranVoidedProd PROD
	  LEFT JOIN [MMS_Archive].[dbo].TranVoided ARCH
	    ON PROD.TranVoidedID = ARCH.TranVoidedID
	   AND ISNULL(PROD.Comments, 7) = ISNULL(ARCH.Comments, 7)
	   AND ISNULL(PROD.EmployeeID, 7) = ISNULL(ARCH.EmployeeID, 7)
	   AND ISNULL(PROD.UTCVoidDateTime, 7) = ISNULL(ARCH.UTCVoidDateTime, 7)
	   AND ISNULL(PROD.VoidDateTime, 7) = ISNULL(ARCH.VoidDateTime, 7)
	   AND ISNULL(PROD.VoidDateTimeZone, 7) = ISNULL(ARCH.VoidDateTimeZone, 7)
	 WHERE ARCH.TranVoidedID IS NULL
	 
	 
	SELECT @Rowcount = COUNT(*) FROM #TranVoidedTemp
	 
	IF @Rowcount <> 0
	BEGIN
	  SET @Message = @Message + ' There are ' + CONVERT(VARCHAR, @Rowcount) + ' different records in TranVoided'
	END
	 
	-----------------------------------------------
	-- Clean up temp tables
	DROP TABLE #TranVoidedProd
	DROP TABLE #TranVoidedTemp

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity
	 
END

