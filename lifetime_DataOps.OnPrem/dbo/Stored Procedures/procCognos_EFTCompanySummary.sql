


CREATE PROC [dbo].[procCognos_EFTCompanySummary] (
  @StartDate SMALLDATETIME,
  @EndDate SMALLDATETIME
)

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

/*	====== Sample Execution ======================================= 

    procCognos_EFTCompanySummary '10/1/2015 12:00 AM', '10/15/2015 12:00 AM'

	=============================================		*/
 
SET @EndDate = DATEADD(DAY,1, @EndDate) -- next day midnght 

SET @StartDate = CASE WHEN @StartDate = 'Jan 1, 1900' THEN DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE()),0) ELSE @StartDate END
SET @EndDate = CASE WHEN @EndDate = 'Jan 1, 1900' THEN CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),101),101) ELSE @EndDate END

DECLARE @HeaderDateRange VARCHAR(33)
DECLARE @ReportRunDateTime VARCHAR(21) 

SET @HeaderDateRange = convert(varchar(12), @StartDate, 107) + ' through ' + convert(varchar(12), @EndDate, 107)
SET @ReportRunDateTime = CONVERT (varchar,getdate(), 107)+ ' ' + substring(CONVERT (varchar,getdate(), 100), 13,8)


SELECT 
		C.ClubName, 
		C.GLClubID,
		VCC.CurrencyCode,
		VR.Description AS RegionDescription,
		VPT.Description AS PaymentTypeDescription,  
		COUNT(EFT.MembershipID) AS TotalTransactionCount, 
		SUM(EFT.EFTAmount + IsNull(EFT.EFTAmountProducts,0)) AS TotalTransactionAmount,
		SUM(CASE WHEN (EFT.Valeftstatusid = 3 AND EFT.EFTAmountProducts = 0) THEN 1 else 0 END) AS DuesApprovedCount,
		SUM(CASE WHEN (EFT.Valeftstatusid = 3 AND EFT.EFTAmountProducts > 0) THEN 1 else 0 END) AS ProductsApprovedCount,
		SUM(CASE WHEN EFT.Valeftstatusid = 3 THEN 1 else 0 END) AS TotalApprovedCount,
		SUM(CASE WHEN EFT.Valeftstatusid = 3 THEN (EFT.EFTAmount)  else 0 END) AS DuesApprovedAmount,
		SUM(CASE WHEN EFT.Valeftstatusid = 3 THEN (IsNull(EFT.EFTAmountProducts,0))  else 0 END) AS ProductsApprovedAmount,
		SUM(CASE WHEN EFT.Valeftstatusid = 3 THEN (EFT.EFTAmount + IsNull(EFT.EFTAmountProducts,0))  else 0 END) AS TotalApprovedAmount,
		SUM(CASE WHEN (EFT.Valeftstatusid = 2 AND EFT.EFTAmountProducts = 0) THEN 1 else 0 END) AS DuesReturnedCount,
		SUM(CASE WHEN (EFT.Valeftstatusid = 2 AND EFT.EFTAmountProducts > 0) THEN 1 else 0 END) AS ProductsReturnedCount,
		SUM(CASE WHEN EFT.Valeftstatusid = 2 THEN 1 else 0 END) AS TotalReturnedCount,
		SUM(CASE WHEN EFT.Valeftstatusid = 2 THEN (EFT.EFTAmount) else 0 END) AS  DuesReturnedAmount,
		SUM(CASE WHEN EFT.Valeftstatusid = 2 THEN (IsNull(EFT.EFTAmountProducts,0)) else 0 END) AS  ProductsReturnedAmount,
		SUM(CASE WHEN EFT.Valeftstatusid = 2 THEN (EFT.EFTAmount + IsNull(EFT.EFTAmountProducts,0)) else 0 END) AS  TotalReturnedAmount,
		MAX(@HeaderDateRange) AS HeaderDateRange,
        MAX(@ReportRunDateTime) AS ReportRunDateTime,
        SUM(CASE WHEN VPT.ValPaymentTypeID in (9,10,13) AND EFT.Valeftstatusid = 3
                 THEN (EFT.EFTAmount + IsNull(EFT.EFTAmountProducts,0)) else 0 END) Accum_ACHApprovedAmt_ByClub, -- ('Individual Checking', 'Savings Account', 'Commercial Checking EFT')		
        SUM(CASE WHEN VPT.ValPaymentTypeID in (3,4) AND EFT.Valeftstatusid = 3
                 THEN (EFT.EFTAmount + IsNull(EFT.EFTAmountProducts,0)) else 0 END) Accum_VISA_MC_ApprovedAmt_ByClub, -- ('VISA', 'MasterCard') 		
        SUM(CASE WHEN VPT.ValPaymentTypeID in (5) AND EFT.Valeftstatusid = 3
                 THEN (EFT.EFTAmount + IsNull(EFT.EFTAmountProducts,0)) else 0 END) Accum_Discover_ApprovedAmt_ByClub, -- ('Discover') 		
        SUM(CASE WHEN VPT.ValPaymentTypeID in (8) AND EFT.Valeftstatusid = 3
                 THEN (EFT.EFTAmount + IsNull(EFT.EFTAmountProducts,0)) else 0 END) Accum_AMEX_ApprovedAmt_ByClub, -- ('American Express')
        MAX(1) UniqueClubFlag 		
			   	

  FROM vMembership MS
  JOIN dbo.vClub C
       ON C.ClubID = MS.ClubID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vEFT EFT
       ON EFT.MembershipID = MS.MembershipID
  JOIN dbo.vValPaymentType VPT
       ON EFT.ValPaymentTypeID = VPT.ValPaymentTypeID
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
 WHERE C.DisplayUIFlag = 1 AND
       EFT.EFTDate > @StartDate AND EFT.EFTDate < @EndDate AND
       VPT.ViewBankAccountTypeFlag = 1 AND       
	   EFT.EFTReturnCodeID is not null AND
	   EFT.EFTReturnCodeID <> 42 AND
       EFT.ValEFTTypeID <> 3 -- refunds are not included
GROUP BY VR.Description, C.ClubName, C.GLClubID, VCC.CurrencyCode,VPT.Description 
Order By VR.Description,C.ClubName,VPT.Description


END
