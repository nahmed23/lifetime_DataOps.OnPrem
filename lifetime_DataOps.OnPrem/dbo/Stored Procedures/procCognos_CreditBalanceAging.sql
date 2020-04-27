




CREATE  PROC [dbo].[procCognos_CreditBalanceAging] (
  @ClubIDList VARCHAR(2000),
  @RegionList VARCHAR(2000),
  @MembershipStatusList VARCHAR(1000),
  @PaymentTypeList VARCHAR(1000),
  @ReportedMembers Varchar(50),
  @CorporatePartnerProgramIDList VARCHAR(8000),
  @CorporatePartnerProgramCompanyIDList Varchar(8000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- display members who have paid LTF for services in advance (Credit Balances.)


-------- Sample execution
---- Exec procCognos_CreditBalanceAging 'All Clubs','Hall-MN-West','Active','Discover','All Memberships','0','0'
-------



DECLARE @ReportRunDateTime VARCHAR(21) 
DECLARE @MembersReportedList VARCHAR(50)
DECLARE @HeaderPaymentTypeList VARCHAR(1000)  

SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')


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
  JOIN #Clubs ON C.ClubID = Convert(INT,#Clubs.ClubID)
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

SET @PaymentTypeList =  REPLACE(@PaymentTypeList, '|', ',')  
SET @MembersReportedList = CASE WHEN @ReportedMembers = 'All Memberships' 
                                THEN 'All Memberships' 
								When @ReportedMembers = 'Employees Only'
								Then 'Employees Only'
								ELSE 'Corporate Partner Program Members' 
								END 
SET @MembershipStatusList =  REPLACE(@MembershipStatusList, '|', ',')  


 CREATE TABLE #ReportDetail (
 ReportRunDateTime Varchar(21),
 ClubName Varchar(50),
 MMSRegion Varchar(50),
 MembershipType Varchar(50),
 MemberID INT,
 FirstName Varchar(50),
 LastName Varchar(50),
 AreaCode Varchar(3),
 Number Varchar(7),
 MembershipPhoneNumber Varchar(15), 
 Dues_0_30_DaysFromTranDate   Decimal(14,4),
 Dues_31_60_DaysFromTranDate  Decimal(14,4),
 Dues_61_90_DaysFromTranDate  Decimal(14,4),
 Dues_Over_90_DaysFromTranDate  Decimal(14,4),
 Products_0_30_DaysFromTranDate  Decimal(14,4),
 Products_31_60_DaysFromTranDate  Decimal(14,4),
 Products_61_90_DaysFromTranDate  Decimal(14,4),
 Products_Over_90_DaysFromTranDate  Decimal(14,4),
 EFTOption Varchar(50),
 EFTPaymentMethod  Varchar(50),
 TranItemID INT,
 TranDate  Datetime,
 PostDateTime Datetime,
 MembershipStatus  Varchar(50),
 LocalCurrencyCode  Varchar(15),
 PlanRate  Decimal(14,4),
 ReportingCurrencyCode  Varchar(15), 
 TranBalanceAmount  Decimal(14,4),
 LocalCurrency_TranBalanceAmount  Decimal(14,2),
 USD_TranBalanceAmount  Decimal(14,4),
 MembershipBalance_EFTAmount_Dues  Decimal(14,4),
 LocalCurrency_MembershipBalance_EFTAmount_Dues  Decimal(14,2),
 USD_MembershipBalance_EFTAmount_Dues  Decimal(14,4),
 MembershipBalance_EFTAmount_Products  Decimal(14,4),
 LocalCurrency_MembershipBalance_EFTAmount_Products  Decimal(14,2),
 USD_MembershipBalance_EFTAmount_Products  Decimal(14,4),
 CorporatePartnerProgramName  Varchar(50),
 CorporatePartnerProgramCompanyName  Varchar(50),
 CorporatePartnerProgramCompanyCode  Varchar(50),
 CorporatePartnerProgramMemberID  INT,
 CorporatePartnerProgramMemberJoinDate  Datetime,
 CorporatePartnerProgramMemberEnrollmentDate  Datetime,
 CorporatePartnerProgramMemberTerminationDate  Datetime,
 HeaderMembershipStatusList  Varchar(500),
 HeaderPaymentTypeList  Varchar(1000), 
 HeaderMembersReportedList  Varchar(50))

 

 IF @ReportedMembers in('All Memberships','Employees Only')
   -----  Standard membership level report returning 1 record per membership
 BEGIN
 INSERT INTO #ReportDetail
 SELECT 
       @ReportRunDateTime AS ReportRunDateTime,
	   C.ClubName, 
	   VR.Description AS MMSRegion, 
	   P.Description AS MembershipType,
       M.MemberID, M.FirstName, M.LastName,
       MSP.AreaCode, MSP.Number,
       '('+ MSP.AreaCode + ')' + SUBSTRING(MSP.Number,1,3) + '-' + SUBSTRING(MSP.Number,4,4) AS MembershipPhoneNumber,
        CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  < 31 AND TB.TranProductCategory = 'Dues'
		     THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Dues_0_30_DaysFromTranDate,
        CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  >= 31 AND DATEDIFF(DD, MMST.TranDate, GETDATE())  < 61 AND TB.TranProductCategory = 'Dues'
		     THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Dues_31_60_DaysFromTranDate,
        CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  >= 61 AND DATEDIFF(DD, MMST.TranDate, GETDATE())  < 91 AND TB.TranProductCategory = 'Dues'
		     THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Dues_61_90_DaysFromTranDate,
        CASE WHEN (DATEDIFF(DD, MMST.TranDate, GETDATE())  >= 91 OR TB.TranItemID IS NULL) AND TB.TranProductCategory = 'Dues'
             THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
             ELSE 0 END Dues_Over_90_DaysFromTranDate,
        CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  < 31 AND TB.TranProductCategory = 'Products'
		     THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Products_0_30_DaysFromTranDate,
        CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  >= 31 AND DATEDIFF(DD, MMST.TranDate, GETDATE())  < 61 AND TB.TranProductCategory = 'Products'
		     THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Products_31_60_DaysFromTranDate,
        CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  >= 61 AND DATEDIFF(DD, MMST.TranDate, GETDATE())  < 91 AND TB.TranProductCategory = 'Products' 
		     THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Products_61_90_DaysFromTranDate,
        CASE WHEN (DATEDIFF(DD, MMST.TranDate, GETDATE())  >= 91 OR TB.TranItemID IS NULL) AND TB.TranProductCategory = 'Products'
             THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
             ELSE 0 END Products_Over_90_DaysFromTranDate,       

       VEO.Description AS EFTOption, 
       VPT.Description AS EFTPaymentMethod, 
       TB.TranItemID, 
       MMST.TranDate, 
       MMST.PostDateTime, 
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
	   MB.EFTAmountProducts * #PlanRate.PlanRate as MembershipBalance_EFTAmount_Products,
       MB.EFTAmountProducts as LocalCurrency_MembershipBalance_EFTAmount_Products,
       MB.EFTAmountProducts * #ToUSDPlanRate.PlanRate as USD_MembershipBalance_EFTAmount_Products,
/***************************************/
       Cast(Null as Varchar(50)) as CorporatePartnerProgramName,
       Cast(Null as Varchar(50)) as CorporatePartnerProgramCompanyName,
       Cast(Null as Varchar(50)) as CorporatePartnerProgramCompanyCode,
       Cast(Null as INT) as CorporatePartnerProgramMemberID,
       Cast(Null as Datetime) as CorporatePartnerProgramMemberJoinDate,
       Cast(Null as Datetime) as CorporatePartnerProgramMemberEnrollmentDate,
       Cast(Null as Datetime) as CorporatePartnerProgramMemberTerminationDate,
       @MembershipStatusList AS HeaderMembershipStatusList,
       @HeaderPaymentTypeList AS HeaderPaymentTypeList,
       @MembersReportedList AS HeaderMembersReportedList
       
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
  Left JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  Left Join vMembershipTypeAttribute MTA
       On MST.MembershipTypeID = MTA.MembershipTypeID
	   AND MTA.ValMembershipTypeAttributeID = 4
  JOIN dbo.vTranBalance TB 
       ON TB.MembershipID = MS.MembershipID
  JOIN dbo.vMembershipBalance MB
       ON MS.MembershipID = MB.MembershipID
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
    WHERE (IsNull(MB.CommittedBalance,0) + IsNull(MB.CommittedBalanceProducts,0)) < 0 
       AND M.ValMemberTypeID = 1 
       --(C.DisplayUIFlag = 1 OR @DisplayUIFlag = 1 ) AND
       AND (MTA.ValMembershipTypeAttributeID = 4 OR @ReportedMembers = 'All Memberships')  ----- #4 = Employee Membership
       AND (ISNULL(VPT.Description, 'Undefined') IN (SELECT Description FROM #PaymentType) OR @PaymentTypeList = 'All')
   Order by VR.Description,C.ClubName,M.MemberID



END


 IF @ReportedMembers in('Corporate Partner Program Members')
    --- Corporate Partner specific report, pulling 1 record per member/program, 
	--- could have multiple records per membership if more than 1 member in membership has a reimburement record, 
	--- also will return more than 1 record for a member if that person has multiple program records

 BEGIN


CREATE TABLE #PartnerProgramIDs (PartnerProgramID INT)
 EXEC procParseIntegerList @CorporatePartnerProgramIDList
 INSERT INTO #PartnerProgramIDs (PartnerProgramID) SELECT StringField FROM #tmpList
 TRUNCATE TABLE #tmpList
  
  IF (SELECT COUNT(*) FROM #PartnerProgramIDs WHERE PartnerProgramID = 0) = 1  -- all Programs option selected
   BEGIN 
    TRUNCATE TABLE #PartnerProgramIDs  
    INSERT INTO #PartnerProgramIDs (PartnerProgramID) SELECT ReimbursementProgramID FROM vReimbursementProgram 
   END


CREATE TABLE #PartnerProgramCompanyIDs (PartnerProgramCompanyID INT)
 EXEC procParseIntegerList @CorporatePartnerProgramCompanyIDList
 INSERT INTO #PartnerProgramCompanyIDs (PartnerProgramCompanyID) SELECT StringField FROM #tmpList
 TRUNCATE TABLE #tmpList
  
  IF (SELECT COUNT(*) FROM #PartnerProgramCompanyIDs WHERE PartnerProgramCompanyID = 0) = 1  -- all Corporate Code option selected
   BEGIN 
    TRUNCATE TABLE #PartnerProgramCompanyIDs  
    INSERT INTO #PartnerProgramCompanyIDs (PartnerProgramCompanyID) SELECT CompanyID FROM vReimbursementProgram Group By CompanyID
   END


      ---- to limit The member reimbusement records to the most recent record for the member within the program
Select MR.MemberID,MR.ReimbursementProgramID, Max(MR.EnrollmentDate) as EnrollmentDate, MR.TerminationDate
INTO #MemberReimbursement
From vMemberReimbursement MR
Join 
(Select MR.MemberID,MR.ReimbursementProgramID,Max(IsNull(MR.TerminationDate,'12/31/2099')) as TerminationDate
From vMemberReimbursement MR
Join #PartnerProgramIDs #PP
On MR.ReimbursementProgramID = #PP.PartnerProgramID
Join vReimbursementProgram RP
On MR.ReimbursementProgramID = RP.ReimbursementProgramID
Join #PartnerProgramCompanyIDs #PPC
On #PPC.PartnerProgramCompanyID = RP.CompanyID
Group by MR.MemberID,MR.ReimbursementProgramID) UniqueProgramMembers
On MR.MemberID = UniqueProgramMembers.MemberID
AND MR.ReimbursementProgramID = UniqueProgramMembers.ReimbursementProgramID
AND IsNull(MR.TerminationDate,'12/31/2099') = UniqueProgramMembers.TerminationDate
Group by MR.MemberID,MR.ReimbursementProgramID,MR.TerminationDate
Order by MR.MemberID



 INSERT INTO #ReportDetail

 SELECT 
       @ReportRunDateTime AS ReportRunDateTime,
	   C.ClubName, 
	   VR.Description AS MMSRegion, 
	   P.Description AS MembershipType,
       PrimaryM.MemberID, 
	   PrimaryM.FirstName, 
	   PrimaryM.LastName,
       MSP.AreaCode, 
	   MSP.Number,
       '('+ MSP.AreaCode + ')' + SUBSTRING(MSP.Number,1,3) + '-' + SUBSTRING(MSP.Number,4,4) AS MembershipPhoneNumber,
        CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  < 31 AND TB.TranProductCategory = 'Dues'
		     THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Dues_0_30_DaysFromTranDate,
        CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  >= 31 AND DATEDIFF(DD, MMST.TranDate, GETDATE())  < 61 AND TB.TranProductCategory = 'Dues'
		     THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Dues_31_60_DaysFromTranDate,
        CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  >= 61 AND DATEDIFF(DD, MMST.TranDate, GETDATE())  < 91 AND TB.TranProductCategory = 'Dues'
		     THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Dues_61_90_DaysFromTranDate,
        CASE WHEN (DATEDIFF(DD, MMST.TranDate, GETDATE())  >= 91 OR TB.TranItemID IS NULL) AND TB.TranProductCategory = 'Dues'
             THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
             ELSE 0 END Dues_Over_90_DaysFromTranDate,
        CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  < 31 AND TB.TranProductCategory = 'Products'
		     THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Products_0_30_DaysFromTranDate,
        CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  >= 31 AND DATEDIFF(DD, MMST.TranDate, GETDATE())  < 61 AND TB.TranProductCategory = 'Products'
		     THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Products_31_60_DaysFromTranDate,
        CASE WHEN DATEDIFF(DD, MMST.TranDate, GETDATE())  >= 61 AND DATEDIFF(DD, MMST.TranDate, GETDATE())  < 91 AND TB.TranProductCategory = 'Products' 
		     THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
			 ELSE 0 END Products_61_90_DaysFromTranDate,
        CASE WHEN (DATEDIFF(DD, MMST.TranDate, GETDATE())  >= 91 OR TB.TranItemID IS NULL) AND TB.TranProductCategory = 'Products'
             THEN TB.TranBalanceAmount * #PlanRate.PlanRate 
             ELSE 0 END Products_Over_90_DaysFromTranDate,       

       VEO.Description AS EFTOption, 
       VPT.Description AS EFTPaymentMethod, 
       TB.TranItemID, 
       MMST.TranDate, 
       MMST.PostDateTime, 
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
	   MB.EFTAmountProducts * #PlanRate.PlanRate as MembershipBalance_EFTAmount_Products,
       MB.EFTAmountProducts as LocalCurrency_MembershipBalance_EFTAmount_Products,
       MB.EFTAmountProducts * #ToUSDPlanRate.PlanRate as USD_MembershipBalance_EFTAmount_Products,
/***************************************/
       RP.ReimbursementProgramName as CorporatePartnerProgramName,
       ReimbCompany.CompanyName as CorporatePartnerProgramCompanyName,
       ReimbCompany.CorporateCode as CorporatePartnerProgramCompanyCode,
       ReimbM.MemberID as CorporatePartnerProgramMemberID,
       ReimbM.JoinDate as CorporatePartnerProgramMemberJoinDate,
       #MR.EnrollmentDate as CorporatePartnerProgramMemberEnrollmentDate,
       #MR.TerminationDate as CorporatePartnerProgramMemberTerminationDate,
       @MembershipStatusList AS HeaderMembershipStatusList,
       @HeaderPaymentTypeList AS HeaderPaymentTypeList,
       @MembersReportedList AS HeaderMembersReportedList
       
  FROM dbo.vClub C
  JOIN dbo.vMembership MS 
       ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID
  JOIN dbo.vMember ReimbM
       ON MS.MembershipID = ReimbM.MembershipID
  JOIN #MemberReimbursement  #MR
       On ReimbM.MemberID = #MR.MemberID
  JOIN vReimbursementProgram RP
       ON #MR.ReimbursementProgramID = RP.ReimbursementProgramID
  LEFT JOIN dbo.vMember PrimaryM
       ON MS.MembershipID = PrimaryM.MembershipID 
	   AND PrimaryM.ValMemberTypeID = 1 
  JOIN vCompany ReimbCompany
       ON RP.CompanyID = ReimbCompany.CompanyID
  JOIN #PartnerProgramIDs  #PP
       On RP.ReimbursementProgramID = #PP.PartnerProgramID
  JOIN #PartnerProgramCompanyIDs #PPC
       ON ReimbCompany.CompanyID = #PPC.PartnerProgramCompanyID
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
  LEFT JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN dbo.vTranBalance TB 
       ON TB.MembershipID = MS.MembershipID
  JOIN dbo.vMembershipBalance MB
       ON MS.MembershipID = MB.MembershipID
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
    WHERE (IsNull(MB.CommittedBalance,0) + IsNull(MB.CommittedBalanceProducts,0)) < 0 
       AND (ISNULL(VPT.Description, 'Undefined') IN (SELECT Description FROM #PaymentType) OR @PaymentTypeList = 'All')
   Order by VR.Description,C.ClubName,PrimaryM.MemberID

   Drop Table #PartnerProgramIDs
   Drop Table #PartnerProgramCompanyIDs
   Drop Table #MemberReimbursement

   End


----- final result

Select ReportRunDateTime,
	   ClubName, 
	   MMSRegion, 
	   MembershipType,
       MemberID, 
	   FirstName, 
	   LastName,
       AreaCode, 
	   Number,
       MembershipPhoneNumber,
       Dues_0_30_DaysFromTranDate,
       Dues_31_60_DaysFromTranDate,
       Dues_61_90_DaysFromTranDate,
       Dues_Over_90_DaysFromTranDate,
       Products_0_30_DaysFromTranDate,
       Products_31_60_DaysFromTranDate,
       Products_61_90_DaysFromTranDate,
       Products_Over_90_DaysFromTranDate,       
       EFTOption, 
       EFTPaymentMethod, 
       TranItemID, 
       TranDate, 
       PostDateTime, 
       MembershipStatus,
/******  Foreign Currency Stuff  *********/
	   LocalCurrencyCode,
       PlanRate,
       ReportingCurrencyCode,
	   TranBalanceAmount,	   
	   LocalCurrency_TranBalanceAmount,	  
	   USD_TranBalanceAmount, 
 	   MembershipBalance_EFTAmount_Dues,
       LocalCurrency_MembershipBalance_EFTAmount_Dues,
       USD_MembershipBalance_EFTAmount_Dues,
	   MembershipBalance_EFTAmount_Products,
       LocalCurrency_MembershipBalance_EFTAmount_Products,
       USD_MembershipBalance_EFTAmount_Products,
/***************************************/
       CorporatePartnerProgramName,
       CorporatePartnerProgramCompanyName,
       CorporatePartnerProgramCompanyCode,
       CorporatePartnerProgramMemberID,
       CorporatePartnerProgramMemberJoinDate,
       CorporatePartnerProgramMemberEnrollmentDate,
       CorporatePartnerProgramMemberTerminationDate,
       HeaderMembershipStatusList,
       HeaderPaymentTypeList,
       HeaderMembersReportedList
From #ReportDetail
Order by ClubName


DROP TABLE #Clubs
DROP TABLE #MembershipStatus
DROP TABLE #PaymentType
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate
Drop Table #ReportDetail


END

