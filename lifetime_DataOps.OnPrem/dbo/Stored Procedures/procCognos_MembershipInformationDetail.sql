


CREATE PROC [dbo].[procCognos_MembershipInformationDetail] (
    @DateFilter VARCHAR(50),
    @ReportStartDate DATETIME,
    @ReportEndDate DATETIME,
    @MMSClubIDList VARCHAR(4000),
    @MembershipTypeList VARCHAR(8000),
    @MembershipStatusDescriptionList VARCHAR(4000),
    @ValTerminationReasonIDList VARCHAR(4000),
    @CorporatePartnerTypeList VARCHAR(8000),
    @PartnerCompanyIDList VARCHAR(8000),
    @PartnerProgramIDList VARCHAR(8000))

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

IF 1=0 BEGIN
       SET FMTONLY OFF
     END

/*
Exec procCognos_MembershipInformationDetail 'Membership Created Date Range','11/25/2016','3/25/2017','196','Loyalty Memberships','Active|Pending Termination','< Ignore this prompt >','< Ignore this prompt >','< Ignore this prompt >','< Ignore this prompt >'
*/


DECLARE @ReportRunDateTime VARCHAR(21)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,GetDate(),100),1,6)+', '+Substring(convert(varchar,GetDate(),100),8,10)+' '+Substring(convert(varchar,GetDate(),100),18,2),'  ',' ')

DECLARE @HeaderDateRange VARCHAR(110)
SET @HeaderDateRange = Replace(Substring(convert(varchar,@ReportStartDate,100),1,6)+', '+Substring(convert(varchar,@ReportStartDate,100),8,4),'  ',' ')
                       + ' through ' + 
                       Replace(Substring(convert(varchar,@ReportEndDate,100),1,6)+', '+Substring(convert(varchar,@ReportEndDate,100),8,4),'  ',' ')

DECLARE @EndDate_FirstOfMonth DateTime
DECLARE @EndDate_SecondOfMonth DateTime
SET @EndDate_FirstOfMonth = (Select CalendarMonthStartingDate from vReportDimDate where CalendarDate = @ReportEndDate)
SET @EndDate_SecondOfMonth =  DateAdd(day,1,@EndDate_FirstOfMonth)



SELECT Cast(item as Int) MMSClubID
  INTO #MMSClubIDList
  FROM fnParsePipeList(@MMSClubIDList)
  GROUP BY item

SELECT DISTINCT ValMembershipStatus.ValMembershipStatusID
  INTO #ValMembershipStatusIDList
  FROM vValMembershipStatus ValMembershipStatus
  JOIN fnParsePipeList(@MembershipStatusDescriptionList) MembershipStatusList
    ON ValMembershipStatus.Description = MembershipStatusList.Item
    OR MembershipStatusList.Item = '< Ignore this prompt >'

DECLARE @HeaderMembershipStatusList VARCHAR(4000)
SET @HeaderMembershipStatusList = CASE WHEN '< Ignore this prompt >' IN (SELECT item FROM fnParsePipeList(@MembershipStatusDescriptionList)) THEN 'All Membership Statuses'
                                       ELSE REPLACE(@MembershipStatusDescriptionList,'|',', ') END

SELECT DISTINCT Item ValTerminationReasonID
  INTO #ValTerminationReasonIDList
  FROM fnParsePipeList(@ValTerminationReasonIDList) ValTerminationReasonIDList

SELECT Cast(MembershipTypeList.Item AS VARCHAR(255)) MembershipType
  INTO #MembershipTypeList
  FROM fnParsePipeList(@MembershipTypeList) MembershipTypeList

CREATE UNIQUE INDEX IX_MembershipType ON #MembershipTypeList(MembershipType)

DECLARE @HeaderMembershipTypeList VARCHAR(8000)
SET @HeaderMembershipTypeList = CASE WHEN '< Ignore this prompt >' IN (SELECT Item FROM fnParsePipeList(@MembershipTypeList)) THEN 'All Membership Types'
                                     ELSE REPLACE(@MembershipTypeList,'|',',') END

SELECT MembershipType.ProductID
INTO #LoyaltyMembershipProductIDs
FROM vMembershipType MembershipType
 JOIN vMembershipTypeAttribute MembershipTypeAttribute
   ON MembershipType.MembershipTypeID = MembershipTypeAttribute.MembershipTypeID
WHERE MembershipTypeAttribute.ValMembershipTypeAttributeID = 49   ----"Loyalty Membership" 

SELECT MembershipType.ProductID
INTO #AccessByPricePaidProductIDs
FROM vMembershipType MembershipType
 JOIN vMembershipTypeAttribute MembershipTypeAttribute
   ON MembershipType.MembershipTypeID = MembershipTypeAttribute.MembershipTypeID
WHERE MembershipTypeAttribute.ValMembershipTypeAttributeID = 67   ----"Access by Price Paid Membership" 

SELECT DISTINCT MMSProductID ProductID
  INTO #IncludeMembershipProducts
  FROM vReportDimProduct
 WHERE SalesCategoryDescription = 'Membership Type'
   AND ((MembershipTypeFoundersFlag = 'N' AND 'All Memberships - Excluding Founders' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeHouseAccountFlag = 'N' AND 'All Memberships - Excluding House Account' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeCorporateFlexFlag = 'Y' AND 'Corporate Flex Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeEmployeeFlag = 'Y' AND 'Employee Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeFlexiblePassFlag = 'Y' AND 'Flexible Pass Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeFoundersFlag = 'Y' AND 'Founders Type Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeHouseAccountFlag = 'Y' AND 'House Account Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeInvestorFlag = 'Y' AND 'Investor Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeMyHealthCheckFlag = 'Y' AND 'myHealthCheck Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeNonAccessFlag = 'Y' AND 'Non-Access Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypePendingNonAccessFlag = 'Y' AND 'Pending Non-Access Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeShortTermFlag = 'Y' AND 'Short Term Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeStudentFlexFlag = 'Y' AND 'Student Flex Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeTradeOutFlag = 'Y' AND 'Trade Out Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeVIPFlag = 'Y' AND 'VIP Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipType26AndUnderFlag = 'Y' AND '26 and Under Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeLifeTimeHealthFlag = 'Y' AND 'Life Time Health Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MMSProductID IN(SELECT ProductID FROM #LoyaltyMembershipProductIDs) AND 'Loyalty Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
		OR (MMSProductID IN(SELECT ProductID FROM #AccessByPricePaidProductIDs) AND 'Access By Price Paid' IN (SELECT MembershipType FROM #MembershipTypeList))
		OR ('< Ignore this prompt >' IN (SELECT MembershipType FROM #MembershipTypeList)))
CREATE UNIQUE CLUSTERED INDEX IX_ProductID ON #IncludeMembershipProducts(ProductID)


DECLARE @CorporateMembershipFlag CHAR(1)
SELECT @CorporateMembershipFlag = CASE WHEN 'Corporate Memberships' IN (SELECT MembershipType FROM #MembershipTypeList) THEN 'Y' ELSE 'N' END

DECLARE @FilterByPartnerProgramFlag CHAR(1)
SET @FilterByPartnerProgramFlag = CASE WHEN '< Ignore this prompt >' IN (SELECT item FROM fnParsePipeList(@CorporatePartnerTypeList))
                                        AND '< Ignore this prompt >' IN (SELECT item FROM fnParsePipeList(@PartnerCompanyIDList))
                                        AND '< Ignore this prompt >' IN (SELECT item FROM fnParsePipeList(@PartnerProgramIDList))
                                            THEN 'N'
                                       ELSE 'Y' END

SELECT DISTINCT
       ReimbursementProgram.ReimbursementProgramID,
       ReimbursementProgram.ReimbursementProgramName ProgramName,
       Company.CompanyID,
       Company.CompanyName,
       Company.AccountOwner AccountOwner,
	   Company.SubsidyMeasurement,
       ValType.Description ProgramType
  INTO #ReimbursementProgram
  FROM vReimbursementProgram ReimbursementProgram
  JOIN vValReimbursementProgramType ValType
   ON ReimbursementProgram.ValReimbursementProgramTypeID = ValType.ValReimbursementProgramTypeID
  JOIN vCompany Company
    ON ReimbursementProgram.CompanyID = Company.CompanyID
  JOIN fnParsePipeList(@CorporatePartnerTypeList) CorporatePartnerTypeList
    ON ValType.Description = CorporatePartnerTypeList.Item
    OR CorporatePartnerTypeList.Item = '< Ignore this prompt >'
  JOIN fnParsePipeList(@PartnerCompanyIDList) PartnerCompanyIDList
    ON CAST(ReimbursementProgram.CompanyID AS VARCHAR) = PartnerCompanyIDList.Item
    OR PartnerCompanyIDList.Item = '< Ignore this prompt >'
  JOIN fnParsePipeList(@PartnerProgramIDList) PartnerProgramIDList
    ON CAST(ReimbursementProgram.ReimbursementProgramID AS VARCHAR) = PartnerProgramIDList.Item
    OR PartnerProgramIDList.Item = '< Ignore this prompt >'
 WHERE ReimbursementProgram.ActiveFlag = 1


DECLARE @HeaderCorporatePartnerTypeList VARCHAR(8000),
        @HeaderPartnerCompanyNameList VARCHAR(8000)


SET @HeaderCorporatePartnerTypeList = 
CASE WHEN '< Ignore this prompt >' IN (SELECT item FROM fnParsePipeList(@CorporatePartnerTypeList))
     THEN ''
     ELSE 'Corporate Partner Type(s): '+ REPLACE(@CorporatePartnerTypeList,'|',',')
END 

SET @HeaderPartnerCompanyNameList = 
CASE WHEN '< Ignore this prompt >' IN (SELECT item FROM fnParsePipeList(@PartnerCompanyIDList))
     THEN ''     
     ELSE 
      'Partner Company Name(s): '+
       STUFF((SELECT DISTINCT ', ' + CompanyName
               FROM vCompany Company
                JOIN fnParsePipeList(@PartnerCompanyIDList) PartnerCompanyIDList
                ON CONVERT(VARCHAR,Company.CompanyID) = PartnerCompanyIDList.Item
               FOR XML PATH(''),ROOT('CompanyNames'),type).value('/CompanyNames[1]','varchar(8000)'),1,1,'')
END


SELECT Membership.MembershipID,
       Membership.ClubID,
       Membership.MembershipTypeID,
       Membership.ValMembershipStatusID,
       Membership.AdvisorEmployeeID,
       Convert(Datetime,Convert(Varchar,Membership.ActivationDate,101),101) ActivationDate,
       Convert(Datetime,Convert(Varchar,Membership.ExpirationDate,101),101) ExpirationDate,
       Membership.CompanyID,
       Membership.ValTerminationReasonID,
       Convert(Datetime,Convert(Varchar,Membership.CancellationRequestDate,101),101) CancellationRequestDate,
       Convert(Datetime,Convert(Varchar,Membership.CreatedDateTime,101),101) CreatedDateTime,
       Membership.ValEFTOptionID,
       Membership.ValMembershipSourceID,
       Convert(Datetime,Convert(Varchar,PrimaryMember.JoinDate,101),101) PrimaryMemberJoinDate,
	   Membership.CurrentPrice
  INTO #Membership
  FROM vMembership Membership
  JOIN #ValMembershipStatusIDList
    ON Membership.ValMembershipStatusID = #ValMembershipStatusIDList.ValMembershipStatusID
  JOIN vMember PrimaryMember
    ON Membership.MembershipID = PrimaryMember.MembershipID
   AND PrimaryMember.ValMemberTypeID = 1
  JOIN #MMSClubIDList
    ON Membership.ClubID = #MMSClubIDList.MMSClubID

SELECT #Membership.MembershipID,
       #Membership.ClubID,
       #Membership.ValMembershipStatusID,
       #Membership.AdvisorEmployeeID,
       #Membership.ActivationDate MembershipActivationDate,
       #Membership.ExpirationDate TerminationDate,
       #Membership.CompanyID,
       #Membership.ValTerminationReasonID,
       #Membership.MembershipTypeID,
       #Membership.CancellationRequestDate,
       #Membership.CreatedDateTime MembershipCreatedDate,
       #Membership.ValEFTOptionID,
       #Membership.ValMembershipSourceID,
	   #Membership.CurrentPrice,
       CASE WHEN @DateFilter = 'Membership Created Date Range' THEN Year(#Membership.CreatedDateTime)
            WHEN @DateFilter = 'Membership Termination Date Range' THEN Year(#Membership.ExpirationDate)
            WHEN @DateFilter = 'Primary Member join Date Range' THEN Year(#Membership.PrimaryMemberJoinDate)
            WHEN @DateFilter = 'Membership Activation Date Range' THEN Year(#Membership.ActivationDate)
            WHEN @DateFilter = 'Cancellation Requested Date Range' THEN Year(#Membership.CancellationRequestDate)
            ELSE Year(GetDate()) END ConversionYear
  INTO #FilteredMemberships
  FROM #Membership
  JOIN vMembershipType MembershipType
    ON #Membership.MembershipTypeID = MembershipType.MembershipTypeID
  JOIN #IncludeMembershipProducts
    ON MembershipType.ProductID = #IncludeMembershipProducts.ProductID
 WHERE ('< Ignore this prompt >' IN (SELECT ValTerminationReasonID FROM #ValTerminationReasonIDList)
        OR Convert(Varchar,#Membership.ValTerminationReasonID) IN (SELECT ValTerminationReasonID FROM #ValTerminationReasonIDList))
   AND ((@DateFilter = 'Non-Terminated Memberships As of Date' AND #Membership.ValMembershipStatusID <> 1 AND @ReportStartDate = Convert(DateTime,Convert(Varchar,GetDate(),101),101))
         OR (@DateFilter = 'Membership Created Date Range' AND #Membership.CreatedDateTime >= @ReportStartDate AND #Membership.CreatedDateTime <= @ReportEndDate)
         OR (@DateFilter = 'Membership Termination Date Range' AND #Membership.ExpirationDate >= @ReportStartDate AND #Membership.ExpirationDate <= @ReportEndDate)
         OR (@DateFilter = 'Primary Member Join Date Range' AND PrimaryMemberJoinDate >= @ReportStartDate AND PrimaryMemberJoinDate <= @ReportEndDate)
         OR (@DateFilter = 'Membership Activation Date Range' AND #Membership.ActivationDate >= @ReportStartDate AND #Membership.ActivationDate <= @ReportEndDate)
         OR (@DateFilter = 'Cancellation Requested Date Range' AND #Membership.CancellationRequestDate >= @ReportStartDate AND #Membership.CancellationRequestDate <= @ReportEndDate))
UNION
SELECT #Membership.MembershipID,
       #Membership.ClubID,
       #Membership.ValMembershipStatusID,
       #Membership.AdvisorEmployeeID,
       #Membership.ActivationDate MembershipActivationDate,
       #Membership.ExpirationDate TerminationDate,
       #Membership.CompanyID,
       #Membership.ValTerminationReasonID,
       #Membership.MembershipTypeID,
       #Membership.CancellationRequestDate,
       #Membership.CreatedDateTime MembershipCreatedDate,
       #Membership.ValEFTOptionID,
       #Membership.ValMembershipSourceID,
	   #Membership.CurrentPrice,
       CASE WHEN @DateFilter = 'Membership Created Date Range' THEN Year(#Membership.CreatedDateTime)
            WHEN @DateFilter = 'Membership Termination Date Range' THEN Year(#Membership.ExpirationDate)
            WHEN @DateFilter = 'Primary Member join Date Range' THEN Year(#Membership.PrimaryMemberJoinDate)
            WHEN @DateFilter = 'Membership Activation Date Range' THEN Year(#Membership.ActivationDate)
            WHEN @DateFilter = 'Cancellation Requested Date Range' THEN Year(#Membership.CancellationRequestDate)
            ELSE Year(GetDate()) END ConversionYear
  FROM #Membership
  JOIN vMember Member
    ON #Membership.MembershipID = Member.MembershipID
   AND Member.ActiveFlag = 1
  LEFT JOIN vMemberReimbursement MemberReimbursement
    ON Member.MemberID = MemberReimbursement.MemberID
   AND MemberReimbursement.EnrollmentDate < @ReportEndDate + 1
   AND (MemberReimbursement.TerminationDate >= @ReportEndDate + 1
        OR MemberReimbursement.TerminationDate IS NULL)
  LEFT JOIN vReimbursementProgram ReimbursementProgram
    ON MemberReimbursement.ReimbursementProgramID = ReimbursementProgram.ReimbursementProgramID
 WHERE @CorporateMembershipFlag = 'Y'
   AND (#Membership.CompanyID IS NOT NULL OR ReimbursementProgram.ActiveFlag = 1)
   AND ('< Ignore this prompt >' IN (SELECT ValTerminationReasonID FROM #ValTerminationReasonIDList) 
        OR Convert(Varchar,#Membership.ValTerminationReasonID) IN (SELECT ValTerminationReasonID FROM #ValTerminationReasonIDList))
   AND ((@DateFilter = 'Non-Terminated Memberships As of Date' AND #Membership.ValMembershipStatusID <> 1 AND @ReportStartDate = Convert(DateTime,Convert(Varchar,GetDate(),101),101))
         OR (@DateFilter = 'Membership Created Date Range' AND #Membership.CreatedDateTime >= @ReportStartDate AND #Membership.CreatedDateTime <= @ReportEndDate)
         OR (@DateFilter = 'Membership Termination Date Range' AND #Membership.ExpirationDate >= @ReportStartDate AND #Membership.ExpirationDate <= @ReportEndDate)
         OR (@DateFilter = 'Primary Member Join Date Range' AND PrimaryMemberJoinDate >= @ReportStartDate AND PrimaryMemberJoinDate <= @ReportEndDate)
         OR (@DateFilter = 'Membership Activation Date Range' AND #Membership.ActivationDate >= @ReportStartDate AND #Membership.ActivationDate <= @ReportEndDate)
         OR (@DateFilter = 'Cancellation Requested Date Range' AND #Membership.CancellationRequestDate >= @ReportStartDate AND #Membership.CancellationRequestDate <= @ReportEndDate))
OPTION(RECOMPILE)

SELECT #FilteredMemberships.MembershipID,
       CAST(CASE WHEN ValProductSalesChannel.ValProductSalesChannelID IS NOT NULL THEN 'LTF E-Commerce - ' + ValProductSalesChannel.Description
                 WHEN MMSTran.EmployeeID IN (-2,-4,-5) THEN Employee.FirstName + ' ' + Employee.LastName
                 WHEN #FilteredMemberships.ValMembershipSourceID = 6 THEN HealthProgramEmployee.FirstName + ' ' + HealthProgramEmployee.LastName
                 ELSE 'MMS' END AS VARCHAR(50)) SalesChannel,
       DENSE_RANK() OVER (PARTITION BY #FilteredMemberships.MembershipID
                              ORDER BY MMSTran.PostDateTime ASC, TranItem.TranItemID ASC) Ranking
  INTO #MembershipSalesChannel
  FROM #FilteredMemberships
  JOIN vMMSTran MMSTran
    ON #FilteredMemberships.MembershipID = MMSTran.MembershipID
   AND MMSTran.PostDateTime >= DATEADD(dd,DateDiff(dd,0,#FilteredMemberships.MembershipCreatedDate),-1)
   AND MMSTran.PostDateTime < DATEADD(dd,DateDiff(dd,0,#FilteredMemberships.MembershipCreatedDate),2)
  JOIN vTranItem TranItem
    ON MMSTran.MMSTranID = TranItem.MMSTranID
  LEFT JOIN vWebOrderMMSTran WebOrderMMSTran
    ON MMSTran.MMSTranID = WebOrderMMSTran.MMSTranID
  LEFT JOIN vWebOrder WebOrder
    ON WebOrderMMSTran.WebOrderID = WebOrder.WebOrderID
  LEFT JOIN vValProductSalesChannel ValProductSalesChannel
    ON WebOrder.ValProductSalesChannelID = ValProductSalesChannel.ValProductSalesChannelID
  LEFT JOIN vEmployee Employee
    ON MMSTran.EmployeeID = Employee.EmployeeID
  LEFT JOIN vEmployee HealthProgramEmployee
    ON HealthProgramEmployee.EmployeeID = -4
 WHERE TranItem.ProductID = 88

DELETE FROM #MembershipSalesChannel WHERE Ranking > 1

SELECT MembershipModificationRequest.MembershipID,
       MembershipModificationRequest.EmployeeID,
       RANK() OVER (PARTITION BY MembershipModificationRequest.MembershipID
                        ORDER BY RequestDateTime DESC, MembershipModificationRequestID DESC) Ranking
  INTO #MembershipModificationEmployees
  FROM #FilteredMemberships
  JOIN vMembershipModificationRequest MembershipModificationRequest
    ON #FilteredMemberships.MembershipID = MembershipModificationRequest.MembershipID
 WHERE MembershipModificationRequest.RequestDateTime >= @ReportStartDate
   AND Convert(Datetime,Convert(Varchar,MembershipModificationRequest.RequestDateTime,101),101) <= @ReportEndDate

SELECT EFT.MembershipID,
       EFT.ValPaymentTypeID,
       RANK() OVER (PARTITION BY EFT.MembershipID
                        ORDER BY EFTDate DESC) Ranking
  INTO #EFT
  FROM vEFT EFT
  JOIN #FilteredMemberships
    ON EFT.MembershipID = #FilteredMemberships.MembershipID

SELECT #FilteredMemberships.MembershipID,
       Member.MemberID,
       Member.ValMemberTypeID,
       RANK() OVER (PARTITION BY #FilteredMemberships.MembershipID, Member.ValMemberTypeID
                        ORDER BY Member.DOB, Member.MemberID) SecondaryRanking
  INTO #MembershipCustomers
  FROM #FilteredMemberships
  JOIN vMember Member
    ON #FilteredMemberships.MembershipID = Member.MembershipID
 WHERE Member.ActiveFlag = 1

SELECT DISTINCT
       #MembershipCustomers.MembershipID,
       #MembershipCustomers.MemberID,
       #MembershipCustomers.ValMemberTypeID,
       #ReimbursementProgram.ProgramName,
       #ReimbursementProgram.AccountOwner,
	   #ReimbursementProgram.SubsidyMeasurement,
       #MembershipCustomers.SecondaryRanking,
       RANK() OVER (PARTITION BY #MembershipCustomers.MemberID, #MembershipCustomers.ValMemberTypeID
                        ORDER BY #ReimbursementProgram.ProgramName) ProgramRanking
  INTO #RankedMembershipCustomersPartnerPrograms
  FROM vMemberReimbursement MemberReimbursement
  JOIN #MembershipCustomers
    ON MemberReimbursement.MemberID = #MembershipCustomers.MemberID
  JOIN #ReimbursementProgram
    ON MemberReimbursement.ReimbursementProgramID = #ReimbursementProgram.ReimbursementProgramID
 WHERE #MembershipCustomers.SecondaryRanking < 3
   AND MemberReimbursement.EnrollmentDate < @ReportEndDate+1
   AND (MemberReimbursement.TerminationDate >= @ReportEndDate+1
        OR MemberReimbursement.TerminationDate IS NULL)


SELECT MembershipID,
       MAX(CASE WHEN ValMemberTypeID = 1 AND ProgramRanking = 1 THEN ProgramName ELSE NULL END) PartnerProgramName1PrimaryMember,
       MAX(CASE WHEN ValMemberTypeID = 1 AND ProgramRanking = 1 THEN AccountOwner ELSE NULL END) AccountOwnerPartnerProgramName1PrimaryMember,
       MAX(CASE WHEN ValMemberTypeID = 1 AND ProgramRanking = 2 THEN ProgramName ELSE NULL END) PartnerProgramName2PrimaryMember,
       MAX(CASE WHEN ValMemberTypeID = 1 AND ProgramRanking = 2 THEN AccountOwner ELSE NULL END) AccountOwnerPartnerProgramName2PrimaryMember,
       MAX(CASE WHEN ValMemberTypeID = 1 AND ProgramRanking = 3 THEN ProgramName ELSE NULL END) PartnerProgramName3PrimaryMember,
       MAX(CASE WHEN ValMemberTypeID = 1 AND ProgramRanking = 3 THEN AccountOwner ELSE NULL END) AccountOwnerPartnerProgramName3PrimaryMember,
       MAX(CASE WHEN ValMemberTypeID = 2 AND ProgramRanking = 1 THEN ProgramName ELSE NULL END) PartnerProgramName1PartnerMember,
       MAX(CASE WHEN ValMemberTypeID = 2 AND ProgramRanking = 1 THEN AccountOwner ELSE NULL END) AccountOwnerPartnerProgramName1PartnerMember,
       MAX(CASE WHEN ValMemberTypeID = 2 AND ProgramRanking = 2 THEN ProgramName ELSE NULL END) PartnerProgramName2PartnerMember,
       MAX(CASE WHEN ValMemberTypeID = 2 AND ProgramRanking = 2 THEN AccountOwner ELSE NULL END) AccountOwnerPartnerProgramName2PartnerMember,
       MAX(CASE WHEN ValMemberTypeID = 2 AND ProgramRanking = 3 THEN ProgramName ELSE NULL END) PartnerProgramName3PartnerMember,
       MAX(CASE WHEN ValMemberTypeID = 2 AND ProgramRanking = 3 THEN AccountOwner ELSE NULL END) AccountOwnerPartnerProgramName3PartnerMember,
       MAX(CASE WHEN ValMemberTypeID = 3 AND SecondaryRanking = 1 AND ProgramRanking = 1 THEN ProgramName ELSE NULL END) PartnerProgramName1SecondaryMember1,
       MAX(CASE WHEN ValMemberTypeID = 3 AND SecondaryRanking = 1 AND ProgramRanking = 1 THEN AccountOwner ELSE NULL END) AccountOwnerPartnerProgramName1SecondaryMember1,
       MAX(CASE WHEN ValMemberTypeID = 3 AND SecondaryRanking = 1 AND ProgramRanking = 2 THEN ProgramName ELSE NULL END) PartnerProgramName2SecondaryMember1,
       MAX(CASE WHEN ValMemberTypeID = 3 AND SecondaryRanking = 1 AND ProgramRanking = 2 THEN AccountOwner ELSE NULL END) AccountOwnerPartnerProgramName2SecondaryMember1,
       MAX(CASE WHEN ValMemberTypeID = 3 AND SecondaryRanking = 1 AND ProgramRanking = 3 THEN ProgramName ELSE NULL END) PartnerProgramName3SecondaryMember1,
       MAX(CASE WHEN ValMemberTypeID = 3 AND SecondaryRanking = 1 AND ProgramRanking = 3 THEN AccountOwner ELSE NULL END) AccountOwnerPartnerProgramName3SecondaryMember1,
       MAX(CASE WHEN ValMemberTypeID = 3 AND SecondaryRanking = 2 AND ProgramRanking = 1 THEN ProgramName ELSE NULL END) PartnerProgramName1SecondaryMember2,
       MAX(CASE WHEN ValMemberTypeID = 3 AND SecondaryRanking = 2 AND ProgramRanking = 1 THEN AccountOwner ELSE NULL END) AccountOwnerPartnerProgramName1SecondaryMember2,
       MAX(CASE WHEN ValMemberTypeID = 3 AND SecondaryRanking = 2 AND ProgramRanking = 2 THEN ProgramName ELSE NULL END) PartnerProgramName2SecondaryMember2,
       MAX(CASE WHEN ValMemberTypeID = 3 AND SecondaryRanking = 2 AND ProgramRanking = 2 THEN AccountOwner ELSE NULL END) AccountOwnerPartnerProgramName2SecondaryMember2,
       MAX(CASE WHEN ValMemberTypeID = 3 AND SecondaryRanking = 2 AND ProgramRanking = 3 THEN ProgramName ELSE NULL END) PartnerProgramName3SecondaryMember2,
       MAX(CASE WHEN ValMemberTypeID = 3 AND SecondaryRanking = 2 AND ProgramRanking = 3 THEN AccountOwner ELSE NULL END) AccountOwnerPartnerProgramName3SecondaryMember2
  INTO #MembershipPartnerPrograms
  FROM #RankedMembershipCustomersPartnerPrograms
 WHERE ProgramRanking < 4
 GROUP BY MembershipID


 ----- Pull most recent month's junior dues assessments for these filtered memberships
 Select #FilteredMemberships.MembershipID,
        Sum(TranItem.ItemAmount) AS JuniorDues
 INTO #MembershipJuniorDues
 FROM #FilteredMemberships
  JOIN vMMSTran MMSTran
    ON #FilteredMemberships.MembershipID = MMSTran.MembershipID
  JOIN vTranItem TranItem
    ON MMSTran.MMSTranID = TranItem.MMSTranID
  WHERE MMSTran.PostDateTime >= @EndDate_FirstOfMonth
    AND MMSTran.PostDateTime < @EndDate_SecondOfMonth
	AND MMSTran.ReasonCodeID = 125  ------- Junior Dues
  GROUP BY #FilteredMemberships.MembershipID

SELECT DISTINCT
       ValRegion.Description MMSRegionName,
       Club.ClubName,
       Club.ClubID,
       #FilteredMemberships.MembershipID,
       ValMembershipStatus.Description MembershipStatus,
       PrimaryMember.MemberID PrimaryMemberID,
       PrimaryMember.FirstName PrimaryMemberFirstName,
       PrimaryMember.LastName PrimaryMemberLastName,
       CASE WHEN PhoneCommunicationPreference.ActiveFlag = 1 THEN 'Do Not Phone' ELSE '' END DoNotPhone,
       ISNULL(ValCommunicationPreferenceStatus.Description,'Subscribed') EmailSolicitationStatus,
       CASE WHEN MailCommunicationPreference.ActiveFlag = 1 THEN 'Do Not Mail' ELSE '' END DoNotMail,
       '('+HomeMembershipPhone.AreaCode+')'+Substring(HomeMembershipPhone.Number,1,3)+'-'+SubString(HomeMembershipPhone.Number,4,4) HomePhone,
       ISNULL('('+WorkMembershipPhone.AreaCode+')'+Substring(WorkMembershipPhone.Number,1,3)+'-'+SubString(WorkMembershipPhone.Number,4,4),'') WorkPhone,
       PrimaryMember.EmailAddress,
       MembershipAddress.AddressLine1 Address1,
       MembershipAddress.AddressLine2 Address2,
       MembershipAddress.City,
       ValState.Description State,
       MembershipAddress.Zip,
       ValCountry.Abbreviation CountryAbbreviation,
       #FilteredMemberships.MembershipCreatedDate,
       #FilteredMemberships.MembershipActivationDate,
       PrimaryMember.JoinDate PrimaryMemberJoinDate,
       #FilteredMemberships.CancellationRequestDate,
       #FilteredMemberships.TerminationDate,
       ValTerminationReason.Description CancellationReason,
       MembershipReportDimProduct.MMSProductID MembershipProductID,
       MembershipReportDimProduct.ProductDescription MembershipTypeDescription,
       ValCheckInGroup.Description CheckInGroupDescription,
       ValCurrencyCode.CurrencyCode LocalCurrencyCode,
	   Cast(ISNULL(#FilteredMemberships.CurrentPrice,0) as Decimal(12,2)) DuesPrice,
       ISNULL(ValPaymentType.Description,'') EFTType,
       ISNULL(ValEFTOption.Description,'') EFTStatus,
	   Cast(MembershipBalance.CurrentBalance as Decimal(12,2)) AccountBalance,
       AdvisorEmployee.LastName + ', ' + AdvisorEmployee.FirstName AdvisorName,
       ISNULL(Company.CorporateCode,'') CorporateCode,
       ISNULL(Company.CompanyName,'') CompanyName,
       ModificationEmployee.EmployeeID ModificationEmployeeID,
       ModificationEmployee.FirstName ModificationEmployeeFirstName,
       ModificationEmployee.LastName ModificationEmployeeLastName,
       @ReportRunDateTime ReportRunDateTime,
       @HeaderDateRange HeaderdateRange,
       @HeaderMembershipStatusList HeaderMembershipStatusList,
       Cast('' as Varchar(79)) HeaderEmptyResult,
       'Local Currency' ReportingCurrencyCode,
       #FilteredMemberships.ConversionYear,
       ISNULL(#MembershipSalesChannel.SalesChannel,'MMS') OriginalSalesChannel,
       ValMembershipSource.Description OriginalMembershipSource,
-------------------------------------------------------------------------
       --Comment out vReportDimProduct source column(s) and change source to vValRevenueReportingCategory.  TCPA project; DJS 09-15-2015
       --MembershipReportDimProduct.MembershipTypeMembershipStatusSummaryGroupDescription MembershipStatusSummaryTypeGroup,
	   CASE WHEN IsNull(VRRC.Description,'NULL') <> 'NULL'
            THEN VRRC.Description
	   ELSE MembershipReportDimProduct.MembershipTypeMembershipStatusSummaryGroupDescription
	   END MembershipStatusSummaryTypeGroup,
-------------------------------------------------------------------------	   
       #MembershipPartnerPrograms.PartnerProgramName1PrimaryMember,
       #MembershipPartnerPrograms.PartnerProgramName2PrimaryMember,
       #MembershipPartnerPrograms.PartnerProgramName3PrimaryMember,
       #MembershipPartnerPrograms.PartnerProgramName1PartnerMember,
       #MembershipPartnerPrograms.PartnerProgramName2PartnerMember,
       #MembershipPartnerPrograms.PartnerProgramName3PartnerMember,
       #MembershipPartnerPrograms.PartnerProgramName1SecondaryMember1,
       #MembershipPartnerPrograms.PartnerProgramName2SecondaryMember1,
       #MembershipPartnerPrograms.PartnerProgramName3SecondaryMember1,
       #MembershipPartnerPrograms.PartnerProgramName1SecondaryMember2,
       #MembershipPartnerPrograms.PartnerProgramName2SecondaryMember2,
       #MembershipPartnerPrograms.PartnerProgramName3SecondaryMember2,
       ISNULL(Company.AccountOwner,'') AccountOwner, --- membership company information
	   ISNULL(Company.SubsidyMeasurement,'') SubsidyMeasurement, --- membership company information
       #MembershipPartnerPrograms.AccountOwnerPartnerProgramName1PrimaryMember,
       #MembershipPartnerPrograms.AccountOwnerPartnerProgramName2PrimaryMember,
       #MembershipPartnerPrograms.AccountOwnerPartnerProgramName3PrimaryMember,
       #MembershipPartnerPrograms.AccountOwnerPartnerProgramName1PartnerMember,
       #MembershipPartnerPrograms.AccountOwnerPartnerProgramName2PartnerMember,
       #MembershipPartnerPrograms.AccountOwnerPartnerProgramName3PartnerMember,     
       #MembershipPartnerPrograms.AccountOwnerPartnerProgramName1SecondaryMember1,
       #MembershipPartnerPrograms.AccountOwnerPartnerProgramName2SecondaryMember1,
       #MembershipPartnerPrograms.AccountOwnerPartnerProgramName3SecondaryMember1,
       #MembershipPartnerPrograms.AccountOwnerPartnerProgramName1SecondaryMember2,
       #MembershipPartnerPrograms.AccountOwnerPartnerProgramName2SecondaryMember2,
       #MembershipPartnerPrograms.AccountOwnerPartnerProgramName3SecondaryMember2,
	   JuniorDues.JuniorDues      
  INTO #Results
  FROM #FilteredMemberships
  JOIN vValMembershipStatus ValMembershipStatus
    ON #FilteredMemberships.ValMembershipStatusID = ValMembershipStatus.ValMembershipStatusID
  JOIN vClub Club
    ON #FilteredMemberships.ClubID = Club.ClubID
  JOIN vValRegion ValRegion
    ON Club.ValRegionID = ValRegion.ValREgionID
  JOIN vValCurrencyCode ValCurrencyCode
    ON Club.ValCurrencyCodeID = ValCurrencyCode.ValCurrencyCodeID
  JOIN vMember PrimaryMember
    ON #FilteredMemberships.MembershipID = PrimaryMember.MembershipID
   AND PrimaryMember.ValMemberTypeID = 1
  LEFT JOIN vEmailAddressStatus EmailAddressStatus
    ON PrimaryMember.EmailAddress = EmailAddressStatus.EmailAddress
  LEFT JOIN vValCommunicationPreferenceStatus ValCommunicationPreferenceStatus
    ON EmailAddressStatus.ValCommunicationPreferenceStatusID = ValCommunicationPreferenceStatus.ValCommunicationPreferenceStatusID
  LEFT JOIN vMembershipCommunicationPreference MailCommunicationPreference
    ON #FilteredMemberships.MembershipID = MailCommunicationPreference.MembershipID
   AND MailCommunicationPreference.ValCommunicationPreferenceID = 1
  LEFT JOIN vMembershipCommunicationPreference PhoneCommunicationPreference
    ON #FilteredMemberships.MembershipID = PhoneCommunicationPreference.MembershipID
   AND PhoneCommunicationPreference.ValCommunicationPreferenceID = 2
  JOIN vMembershipAddress MembershipAddress
    ON #FilteredMemberships.MembershipID = MembershipAddress.MembershipID
   AND MembershipAddress.ValAddressTypeID = 1
  LEFT JOIN vValState ValState
    ON MembershipAddress.ValStateID = ValState.ValStateID
  LEFT JOIN vValCountry ValCountry
    ON MembershipAddress.ValCountryID = ValCountry.ValCountryID
  LEFT JOIN vMembershipPhone HomeMembershipPhone
    ON #FilteredMemberships.MembershipID = HomeMembershipPhone.MembershipID
   AND HomeMembershipPhone.ValPhoneTypeID = 1
  LEFT JOIN vMembershipPhone WorkMembershipPhone
    ON #FilteredMemberships.MembershipID = WorkMembershipPhone.MembershipID
   AND WorkMembershipPhone.ValPhoneTypeID = 2
  JOIN vMembershipType MembershipType
    ON #FilteredMemberships.MembershiPtypeID = MembershipType.MembershipTypeID
-----------------------------------------------------------------
  JOIN vReportDimProduct MembershipReportDimProduct
    ON MembershipType.ProductID = MembershipReportDimProduct.MMSProductID
-----------------------------------------------------------------
---  Add logic to enable using VMTA_Rev.Description if 
---  MembershipReportDimProduct.MembershipTypeMembershipStatusSummaryGroupDescription is not avail. TCPA project; DJS 09-01-2015
  JOIN  vMembershipTypeAttribute MTA
     ON #FilteredMemberships.MembershipTypeID = MTA.MembershipTypeID
  Join vValMembershipTypeAttribute VMTA_Rev
     ON MTA.ValMembershipTypeAttributeID = VMTA_Rev.ValMembershipTypeAttributeID
	 AND VMTA_Rev.ValMembershipTypeAttributeID in (67,11,14,22,25,26,27,5,6,7,8,9) ---- all possible Revenue Reporting Categories
  LEFT JOIN vMembershipAttribute MA
     On #FilteredMemberships.MembershipID = MA.MembershipID
	 And IsNull(MA.EffectiveThruDateTime,'12/31/2100') > @ReportEndDate
	 AND MA.EffectiveFromDateTime <= @ReportEndDate
	 AND MA.ValMembershipAttributeTypeID = 3
  LEFT JOIN vSalesPromotion SP
     On MA.AttributeValue = SP.SalesPromotionID
  LEFT JOIN vValRevenueReportingCategory VRRC
     ON SP.ValRevenueReportingCategoryID = VRRC.ValRevenueReportingCategoryID
-----------------------------------------------------------------  
  JOIN vValCheckInGroup ValCheckInGroup
    ON MembershipType.ValCheckInGroupID = ValCheckInGroup.ValCheckInGroupID
  LEFT JOIN vValTerminationReason ValTerminationReason
    ON #FilteredMemberships.ValTerminationReasonID = ValTerminationReason.ValTerminationReasonID
  LEFT JOIN vEmployee AdvisorEmployee
    ON #FilteredMemberships.AdvisorEmployeeID = AdvisorEmployee.EmployeeID
  JOIN vMembershipBalance MembershipBalance
    ON #FilteredMemberships.MembershipID = MembershipBalance.MembershipID
  LEFT JOIN #MembershipModificationEmployees
    ON #FilteredMemberships.MembershipID = #MembershipModificationEmployees.MembershipID
   AND #MembershipModificationEmployees.Ranking = 1
  LEFT JOIN vEmployee ModificationEmployee
    ON #MembershipModificationEmployees.EmployeeID = ModificationEmployee.EmployeeID
  LEFT JOIN vValEFTOption ValEFTOption
    ON #FilteredMemberships.ValEFTOptionID = ValEFTOption.ValEFTOptionID
  LEFT JOIN #EFT
    ON #FilteredMemberships.MembershipID = #EFT.MembershipID
   AND #EFT.Ranking = 1
  LEFT JOIN vValPaymentType ValPaymentType
    ON #EFT.ValPaymentTypeID = ValPaymentType.ValPaymentTypeID
  LEFT JOIN vCompany Company
    ON #FilteredMemberships.CompanyID = Company.CompanyID
  LEFT JOIN #MembershipSalesChannel
    ON #FilteredMemberships.MembershipID = #MembershipSalesChannel.MembershipID
  LEFT JOIN vValMembershipSource ValMembershipSource
    ON #FilteredMemberships.ValMembershipSourceID = ValMembershipSource.ValMembershipSourceID
  LEFT JOIN #MembershipPartnerPrograms
    ON #FilteredMemberships.MembershipID = #MembershipPartnerPrograms.MembershipID
  LEFT JOIN #MembershipJuniorDues JuniorDues
    ON #FilteredMemberships.MembershipID = JuniorDues.MembershipID
 WHERE @FilterByPartnerProgramFlag = 'N'
    OR (@FilterByPartnerProgramFlag = 'Y'
        AND #MembershipPartnerPrograms.MembershipID IS NOT NULL)

SELECT MMSRegionName,
       ClubName,
       ClubID,
       #Results.MembershipID,
       MembershipStatus,
       PrimaryMemberID,
       PrimaryMemberFirstName,
       PrimaryMemberLastName,
       DoNotPhone,
       EmailSolicitationStatus,
       DoNotMail,
       HomePhone,
       WorkPhone,
       EmailAddress,
       Address1,
       Address2,
       City,
       State,
       Zip,
       CountryAbbreviation,
       Cast(Replace(Substring(convert(varchar,#Results.MembershipCreatedDate,100),1,6)+', '+Substring(convert(varchar,#Results.MembershipCreatedDate,100),8,4),'  ',' ') AS VARCHAR(12)) MembershipCreatedDate,
       Cast(Replace(Substring(convert(varchar,#Results.MembershipActivationDate,100),1,6)+', '+Substring(convert(varchar,#Results.MembershipActivationDate,100),8,4),'  ',' ') AS VARCHAR(12)) MembershipActivationDate,
       Cast(Replace(Substring(convert(varchar,#Results.PrimaryMemberJoinDate,100),1,6)+', '+Substring(convert(varchar,#Results.PrimaryMemberJoinDate,100),8,4),'  ',' ') AS VARCHAR(12)) PrimaryMemberJoinDate,
       Cast(Replace(Substring(convert(varchar,#Results.CancellationRequestDate,100),1,6)+', '+Substring(convert(varchar,#Results.CancellationRequestDate,100),8,4),'  ',' ') AS VARCHAR(12)) CancellationRequestDate,
       Cast(Replace(Substring(convert(varchar,#Results.TerminationDate,100),1,6)+', '+Substring(convert(varchar,#Results.TerminationDate,100),8,4),'  ',' ') AS VARCHAR(12)) TerminationDate,
       CancellationReason,
       MembershipProductID,
       MembershipTypeDescription,
       CheckInGroupDescription,
       LocalCurrencyCode,
       DuesPrice,
       EFTType,
       EFTStatus,
       AccountBalance,
       AdvisorName,
       CorporateCode,
       CompanyName,
       ModificationEmployeeID,
       ModificationEmployeeFirstName,
       ModificationEmployeeLastName,
       ReportRunDateTime,
       HeaderDateRange,
       HeaderMembershipStatusList,
       HeaderEmptyResult,
       ReportingCurrencyCode,
       OriginalSalesChannel,
       OriginalMembershipSource,
---------------------------------
       MembershipStatusSummaryTypeGroup,
---------------------------------
	   @HeaderMembershipTypeList HeaderMembershipTypeList,
       PartnerProgramName1PrimaryMember,
       PartnerProgramName2PrimaryMember,
       PartnerProgramName3PrimaryMember,
       PartnerProgramName1PartnerMember,
       PartnerProgramName2PartnerMember,
       PartnerProgramName3PartnerMember,
       PartnerProgramName1SecondaryMember1,
       PartnerProgramName2SecondaryMember1,
       PartnerProgramName3SecondaryMember1,
       PartnerProgramName1SecondaryMember2,
       PartnerProgramName2SecondaryMember2,
       PartnerProgramName3SecondaryMember2,
       ISNULL(AccountOwner,'') CompanyAccountOwner, 
	   ISNULL(SubsidyMeasurement,'') CompanySubsidyMeasurement,
       AccountOwnerPartnerProgramName1PrimaryMember,
       AccountOwnerPartnerProgramName2PrimaryMember,
       AccountOwnerPartnerProgramName3PrimaryMember,
       AccountOwnerPartnerProgramName1PartnerMember,
       AccountOwnerPartnerProgramName2PartnerMember,
       AccountOwnerPartnerProgramName3PartnerMember,     
       AccountOwnerPartnerProgramName1SecondaryMember1,
       AccountOwnerPartnerProgramName2SecondaryMember1,
       AccountOwnerPartnerProgramName3SecondaryMember1,
       AccountOwnerPartnerProgramName1SecondaryMember2,
       AccountOwnerPartnerProgramName2SecondaryMember2,
       AccountOwnerPartnerProgramName3SecondaryMember2,   
       @HeaderCorporatePartnerTypeList HeaderCorporatePartnerTypeList,
       @HeaderPartnerCompanyNameList HeaderPartnerCompanyNameList,
	   JuniorDues,
	   @EndDate_FirstOfMonth JuniorDuesDate
  FROM #Results
UNION ALL
SELECT Cast(NULL as Varchar(50)) MMSRegionName,
       Cast(NULL as Varchar(50)) ClubName,
       NULL ClubID,
       NULL MembershipID,
       Cast(NULL as Varchar(50)) MembershipStatus,
       NULL PrimaryMemberID,
       Cast(NULL as Varchar(50)) PrimaryMemberFirstName,
       Cast(NULL as Varchar(80)) PrimaryMemberLastName,
       Cast(NULL as Varchar(12)) DoNotPhone,
       Cast(NULL as Varchar(50)) EmailSolicitiationStatus,
       Cast(NULL as Varchar(11)) DoNotMail,
       Cast(NULL as Varchar(13)) HomePhone,
       Cast(NULL as Varchar(13)) WorkPhone,
       Cast(NULL as Varchar(140)) EmailAddress,
       Cast(NULL as Varchar(50)) Address1,
       Cast(NULL as Varchar(50)) Address2,
       Cast(NULL as Varchar(50)) City,
       Cast(NULL as Varchar(50)) State,
       Cast(NULL as Varchar(11)) Zip,
       Cast(NULL as Varchar(15)) CountryAbbreviation,
       Cast(NULL as Varchar(12)) MembershipCreatedDate,
       Cast(NULL as Varchar(12)) MembershipActivationDate,
       Cast(NULL as Varchar(12)) PrimaryMemberJoinDate,
       Cast(NULL as Varchar(12)) CancellationRequestDate,
       Cast(NULL as Varchar(12)) TerminationDate,
       Cast(NULL as Varchar(12)) CancellationReason,
       NULL MembershipProductID,
       Cast(NULL as Varchar(50)) MembershipTypeDescription,
       Cast(NULL as Varchar(50)) CheckInGroupDescription,
       Cast(NULL as Varchar(15)) LocalCurrencyCode,
       Cast(NULL as Decimal(12,2)) DuesPrice,
       Cast(NULL as Varchar(50)) EFTType,
       Cast(NULL as Varchar(50)) EFTStatus,
       Cast(NULL as Decimal(12,2)) AccountBalance,
       Cast(NULL as Varchar(102)) AdvisorName,
       Cast(NULL as Varchar(50)) CorporateCode,
       Cast(NULL as Varchar(50)) CompanyName,
       NULL ModificationEmployeeID,
       Cast(NULL as Varchar(50)) ModificationEmployeeFirstName,
       Cast(NULL as Varchar(50)) ModificationEmployeeLastName,
       @ReportRunDateTime ReportRunDateTime,
       @HeaderDateRange HeaderDateRange,
       @HeaderMembershipStatusList HeaderMembershipStatusList,
       'There are no memberships available for the selected parameters.  Please re-try.' HeaderEmptyResult,
       Cast(NULL as Varchar(50)) ReportingCurrencyCode,
       CAST(NULL as Varchar(50)) OriginalSalesChannel,
       CAST(NULL as Varchar(50)) OriginalMembershipSource,
       CAST(NULL as Varchar(50)) MembershipStatusSummaryTypeGroup,
       @HeaderMembershipTypeList HeaderMembershipTypeList,
       CAST(NULL as Varchar(50)) PartnerProgramName1PrimaryMember,
       CAST(NULL as Varchar(50)) PartnerProgramName2PrimaryMember,
       CAST(NULL as Varchar(50)) PartnerProgramName3PrimaryMember,
       CAST(NULL as Varchar(50)) PartnerProgramName1PartnerMember,
       CAST(NULL as Varchar(50)) PartnerProgramName2PartnerMember,
       CAST(NULL as Varchar(50)) PartnerProgramName3PartnerMember,
       CAST(NULL as Varchar(50)) PartnerProgramName1SecondaryMember1,
       CAST(NULL as Varchar(50)) PartnerProgramName2SecondaryMember1,
       CAST(NULL as Varchar(50)) PartnerProgramName3SecondaryMember1,
       CAST(NULL as Varchar(50)) PartnerProgramName1SecondaryMember2,
       CAST(NULL as Varchar(50)) PartnerProgramName2SecondaryMember2,
       CAST(NULL as Varchar(50)) PartnerProgramName3SecondaryMember2,
       CAST(NULL as Varchar(100)) CompanyAccountOwner, 
	   CAST(NULL as Varchar(50)) CompanySubsidyMeasurement, 
       CAST(NULL as Varchar(50)) AccountOwnerPartnerProgramName1PrimaryMember,
       CAST(NULL as Varchar(50)) AccountOwnerPartnerProgramName2PrimaryMember,
       CAST(NULL as Varchar(50)) AccountOwnerPartnerProgramName3PrimaryMember,
       CAST(NULL as Varchar(50)) AccountOwnerPartnerProgramName1PartnerMember,
       CAST(NULL as Varchar(50)) AccountOwnerPartnerProgramName2PartnerMember,
       CAST(NULL as Varchar(50)) AccountOwnerPartnerProgramName3PartnerMember,     
       CAST(NULL as Varchar(50)) AccountOwnerPartnerProgramName1SecondaryMember1,
       CAST(NULL as Varchar(50)) AccountOwnerPartnerProgramName2SecondaryMember1,
       CAST(NULL as Varchar(50)) AccountOwnerPartnerProgramName3SecondaryMember1,
       CAST(NULL as Varchar(50)) AccountOwnerPartnerProgramName1SecondaryMember2,
       CAST(NULL as Varchar(50)) AccountOwnerPartnerProgramName2SecondaryMember2,
       CAST(NULL as Varchar(50)) AccountOwnerPartnerProgramName3SecondaryMember2,
       @HeaderCorporatePartnerTypeList HeaderCorporatePartnerTypeList,
       @HeaderPartnerCompanyNameList HeaderPartnerCompanyNameList,
	   Cast(NULL as Decimal(12,2)) JuniorDues,
	   @EndDate_FirstOfMonth JuniorDuesDate
 WHERE (SELECT COUNT(*) FROM #Results) = 0
   AND (@DateFilter <> 'Non-Terminated Memberships As of Date'
        OR (@DateFilter = 'Non-Terminated Memberships As of Date'
            AND @ReportStartDate = Convert(Datetime,Convert(Varchar,GetDate(),101),101)))
 ORDER BY MMSRegionName, ClubName, PrimaryMemberLastName, PrimaryMemberFirstName, PrimaryMemberID

DROP TABLE #MMSClubIDList
DROP TABLE #ValMembershipStatusIDList
DROP TABLE #ValTerminationReasonIDList
DROP TABLE #LoyaltyMembershipProductIDs
DROP TABLE #AccessByPricePaidProductIDs
DROP TABLE #MembershipTypeList
DROP TABLE #IncludeMembershipProducts
DROP TABLE #ReimbursementProgram
DROP TABLE #EFT
DROP TABLE #Membership
DROP TABLE #FilteredMemberships
DROP TABLE #MembershipSalesChannel
DROP TABLE #MembershipModificationEmployees
DROP TABLE #MembershipCustomers
DROP TABLE #RankedMembershipCustomersPartnerPrograms
DROP TABLE #MembershipPartnerPrograms
DROP TABLE #MembershipJuniorDues
DROP TABLE #Results


END


