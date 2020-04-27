



CREATE PROC [dbo].[procCognos_DelinquentAgingDetail] (
  @ClubIDList VARCHAR(2000),
  @RegionList VARCHAR(2000),
  @MembershipStatusList VARCHAR(1000),
  @EmployeeOnlyFlag INT,  
  @PaymentTypeList VARCHAR(1000),
  @EarliestMembershipTerminationDate Datetime  
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON


--
-- returns delinquent accounts within specified parameters 
-- display members who owe LTF 
--

---------- Sample execution
---- Exec procCognos_DelinquentAgingDetail '151','Hall-MN-West','Active',0,'VISA','1/2/2012'
----------

DECLARE @ReportRunDateTime VARCHAR(21), @MembersReportedList VARCHAR(50), @HeaderPaymentTypeList VARCHAR(1000) 
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')

Declare @AdjustedEarliestMembershipTerminationDate DateTime
Set @AdjustedEarliestMembershipTerminationDate = CASE WHEN @EarliestMembershipTerminationDate = '1/2/1900'
                                                      THEN DATEADD(MONTH,-6,GETDATE())    ----- returns a calculated date of 6 months prior to the run date
                                                      WHEN @MembershipStatusList like '%Terminated%'
													  THEN @EarliestMembershipTerminationDate
													  WHEN @MembershipStatusList like '%All Membership Statuses%'
													  THEN @EarliestMembershipTerminationDate
													  ELSE '1/1/1900'
													  END



CREATE TABLE #tmpList (StringField VARCHAR(50))

   SELECT DISTINCT Club.ClubID 
  INTO #Clubs
  FROM vClub Club
  JOIN fnParsePipeList(@ClubIDList) MMSClubIDList
    ON Convert(Varchar,Club.ClubID) = MMSClubIDList.Item
    OR @ClubIDList like '%All Clubs%'
  JOIN vValRegion ValRegion
    ON Club.ValRegionID = ValRegion.ValRegionID
  JOIN fnParsePipeList(@RegionList) RegionList
    ON ValRegion.Description = RegionList.Item
      OR @RegionList like '%All Regions%'

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = 'USD'
/***************************************/

CREATE TABLE #MembershipStatus (Description VARCHAR(50))
       IF SUBSTRING(@MembershipStatusList,1,3) <> 'All'
       BEGIN
           EXEC procParseStringList @MembershipStatusList
           INSERT INTO #MembershipStatus (Description) SELECT StringField FROM #tmpList
           TRUNCATE TABLE #tmpList
       END
       ELSE
	BEGIN
            INSERT INTO #MembershipStatus VALUES('All')
	END
SET @MembershipStatusList =  REPLACE(@MembershipStatusList, '|', ',')  

SET @HeaderPaymentTypeList =  REPLACE(@PaymentTypeList, '|', ',')  
CREATE TABLE #PaymentType (Description VARCHAR(50))
       IF SUBSTRING(@PaymentTypeList,1,3) <> 'All'
        BEGIN
           EXEC procParseStringList @PaymentTypeList
           INSERT INTO #PaymentType (Description) SELECT StringField FROM #tmpList
           TRUNCATE TABLE #tmpList
        END
       ELSE
	    BEGIN
           INSERT INTO #PaymentType VALUES('All')
           SET @PaymentTypeList = SUBSTRING(@PaymentTypeList,1,3)
	    END

SET @MembersReportedList = CASE WHEN @EmployeeOnlyFlag = 0 
                                THEN 'All Members' 
								WHEN @EmployeeOnlyFlag = 2
								THEN 'Blast Call Formatting' 
								ELSE 'Employees Only' END 

   SELECT 
       C.ClubName, 
       VR.Description AS MMSRegion, 
       P.Description AS MembershipType,
       M.MemberID, M.MembershipID, M.FirstName, M.LastName,
       MSP.AreaCode, MSP.Number, 
       '('+ MSP.AreaCode + ')' + SUBSTRING(MSP.Number,1,3) + '-' + SUBSTRING(MSP.Number,4,4) AS MembershipPhoneNumber,
       VEO.Description AS EFTOption, VPT.Description AS EFTPaymentMethod, 
       TB.TranItemID, MMST.TranDate, MMST.PostDateTime,
       VMSS.Description AS MembershipStatus,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   TB.TranBalanceAmount * #PlanRate.PlanRate as TranBalanceAmount,	   
	   TB.TranBalanceAmount as LocalCurrency_TranBalanceAmount,	  
	   TB.TranBalanceAmount * #ToUSDPlanRate.PlanRate as USD_TranBalanceAmount,
       MB.EFTAmount * #PlanRate.PlanRate as MembershipBalance_EFTAmount_Dues,
       MB.EFTAmount as LocalCurrency_MembershipBalance_EFTAmount_Dues,
       MB.EFTAmount * #ToUSDPlanRate.PlanRate as USD_MembershipBalance_EFTAmount_Dues,
       IsNull(MB.EFTAmountProducts,0) * #PlanRate.PlanRate as MembershipBalance_EFTAmount_Products,
       IsNull(MB.EFTAmountProducts,0) as LocalCurrency_MembershipBalance_EFTAmount_Products,
       IsNull(MB.EFTAmountProducts,0) * #ToUSDPlanRate.PlanRate as USD_MembershipBalance_EFTAmount_Products,       
        CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  < 31 AND TB.TranProductCategory = 'Dues'   
		     THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Dues_0_30_DaysFromTranDate,
        CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  >= 31 AND DATEDIFF(DD, MMST.TranDate, GETDATE())  < 61 AND TB.TranProductCategory = 'Dues'   
		     THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Dues_31_60_DaysFromTranDate,
        CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  >= 61 AND DATEDIFF(DD, MMST.TranDate, GETDATE())  < 91 AND TB.TranProductCategory = 'Dues'
			 THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Dues_61_90_DaysFromTranDate,
		CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  >= 91 AND DATEDIFF(DD, MMST.TranDate, GETDATE())  <= 120 AND TB.TranProductCategory = 'Dues'
			 THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Dues_91_120_DaysFromTranDate,
        CASE WHEN (DATEDIFF(DD, MMST.TranDate, GETDATE())  > 120 OR TB.TranItemID IS NULL) AND TB.TranProductCategory = 'Dues'   
             THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
             ELSE 0 END Dues_Over_120_DaysFromTranDate,
        CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  < 31 AND TB.TranProductCategory = 'Products'   
		     THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Products_0_30_DaysFromTranDate,
        CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  >= 31 AND DATEDIFF(DD, MMST.TranDate, GETDATE())  < 61 AND TB.TranProductCategory = 'Products'  
		     THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Products_31_60_DaysFromTranDate,
        CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  >= 61 AND DATEDIFF(DD, MMST.TranDate, GETDATE())  < 91 AND TB.TranProductCategory = 'Products'   
		     THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Products_61_90_DaysFromTranDate,
		CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  >= 91 AND DATEDIFF(DD, MMST.TranDate, GETDATE())  <= 120 AND TB.TranProductCategory = 'Products'   
		     THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Products_91_120_DaysFromTranDate,
        CASE WHEN (DATEDIFF(DD, MMST.TranDate, GETDATE())  > 120 OR TB.TranItemID IS NULL) AND TB.TranProductCategory = 'Products'   
             THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
             ELSE 0 END Products_Over_120_DaysFromTranDate,
/***************************************/
       MS.CreatedDateTime as MembershipCreatedDate,
       M.JoinDate as PrimaryMemberJoinDate,
       VMS.Description as OriginalMembershipSalesChannel,
       M.EmailAddress as PrimaryMemberEMailAddress,
       MA.AddressLine1,
       MA.AddressLine2,
       MA.City,
       MA.Zip,
       ST.Abbreviation as StateAbbreviation,
       vTR.Description AS TerminationReason,
       MS.CancellationRequestDate AS CancellationRequestDate,
       MS.ExpirationDate AS TerminationDate,
       @ReportRunDateTime AS ReportRunDateTime,
       @MembershipStatusList AS HeaderMembershipStatusList,
       @HeaderPaymentTypeList AS HeaderPaymentTypeList,
       @MembersReportedList AS HeaderMembersReportedList,
	   @AdjustedEarliestMembershipTerminationDate AS EarliestMembershipTerminationDate,
	   VPT.Description as PaymentType

  FROM dbo.vClub C
  JOIN dbo.vMembership MS 
       ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID 
  JOIN dbo.vMember M
       ON MS.MembershipID = M.MembershipID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID 
  JOIN dbo.vValMembershipStatus VMSS
       ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
  JOIN #MembershipStatus MT
       ON VMSS.Description = MT.Description OR MT.Description = 'All'
  JOIN dbo.vValEFTOption VEO
       ON VEO.ValEFTOptionID = MS.ValEFTOptionID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN dbo.vTranBalance TB 
       ON TB.MembershipID = MS.MembershipID
  JOIN dbo.vMembershipBalance MB
       ON M.MembershipID = MB.MembershipID
  LEFT OUTER JOIN dbo.vTranItem TI 
       ON (TB.TranItemID = TI.TranItemID) 
  LEFT OUTER JOIN dbo.vMMSTran MMST 
       ON (TI.MMSTranID = MMST.MMSTranID)
  LEFT OUTER JOIN dbo.vPrimaryPhone PP 
       ON (PP.MembershipID = MS.MembershipID) 
  LEFT OUTER JOIN dbo.vMembershipPhone MSP 
       ON (PP.MembershipID = MSP.MembershipID AND 
       PP.ValPhoneTypeID = MSP.ValPhoneTypeID) 
  LEFT OUTER JOIN dbo.vEFTAccountDetail EAD 
       ON (MS.MembershipID = EAD.MembershipID) 
  LEFT OUTER JOIN dbo.vValPaymentType VPT 
       ON (EAD.ValPaymentTypeID = VPT.ValPaymentTypeID)
  LEFT OUTER JOIN dbo.vValMembershipSource VMS
       ON VMS.ValMembershipSourceID = MS.ValMembershipSourceID
  LEFT OUTER JOIN dbo.vMembershipAddress MA
       ON MA.MembershipID = MS.MembershipID
  LEFT OUTER JOIN dbo.vValState ST
       ON ST.ValStateID = MA.ValStateID
  LEFT OUTER JOIN dbo.vValTerminationReason vTR
       ON vTR.ValTerminationReasonID = MS.ValTerminationReasonID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(GETDATE()) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(GETDATE()) = #ToUSDPlanRate.PlanYear
/*******************************************/
    WHERE 
       ((MB.EFTAmount >= 15 OR (MB.EFTAmount >= MS.CurrentPrice AND MB.EFTAmount <>0)) OR IsNull(MB.EFTAmountProducts,0) > 0)  
	   AND M.ValMemberTypeID = 1 
       AND (P.Description LIKE '%Employee%' OR @EmployeeOnlyFlag = 0 OR @EmployeeOnlyFlag = 2 )
       AND (ISNULL(VPT.Description, 'Undefined') IN (SELECT Description FROM #PaymentType) OR @PaymentTypeList = 'All')
	   AND (MS.ExpirationDate >= @AdjustedEarliestMembershipTerminationDate or IsNull(MS.ExpirationDate,'1/1/1900') = '1/1/1900') 


DROP TABLE #Clubs
DROP TABLE #MembershipStatus
DROP TABLE #PaymentType
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate


END




