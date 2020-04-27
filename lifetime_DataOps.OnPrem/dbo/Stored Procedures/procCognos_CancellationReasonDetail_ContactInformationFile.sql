
CREATE PROC [dbo].[procCognos_CancellationReasonDetail_ContactInformationFile] (
     @InputCancellationReportType VARCHAR(50),
     @InputBeginningDate DATETIME,
     @InputEndingDate DATETIME,
     @MMSClubIDList VARCHAR(4000),
     @InputMembershipFilter VARCHAR(50),
     @ValTerminationReasonIDList VARCHAR(4000)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @HeaderDateRange Varchar(110)
DECLARE @ReportRunDateTime VARCHAR(21)

SET @HeaderDateRange = Replace(Substring(convert(varchar,@InputBeginningDate,100),1,6)+', '+Substring(convert(varchar,@InputBeginningDate,100),8,4),'  ',' ')
                       + ' through ' + 
                       Replace(Substring(convert(varchar,@InputEndingDate,100),1,6)+', '+Substring(convert(varchar,@InputEndingDate,100),8,4),'  ',' ')
SET @ReportRunDateTime = Replace(Substring(convert(varchar, GetDate(), 100),1,6)+', '+Substring(convert(varchar, GetDate(), 100),8,10)+' '+Substring(convert(varchar,GetDate(), 100),18,2),'  ',' ')

CREATE TABLE #tmpList(StringField Varchar(50))

EXEC procParseIntegerList @MMSClubIDList
SELECT StringField MMSClubID
INTO #MMSClubIDList
FROM #tmpList

TRUNCATE TABLE #tmpList

EXEC procParseStringList @ValTerminationReasonIDList
SELECT StringField ValTerminationReasonID
INTO #ValTerminationReasonIDList
FROM #tmpList

DECLARE @CancellationFlag CHAR(1)
SELECT @CancellationFlag = CASE WHEN @InputCancellationReportType = 'Cancellation Requested Date' THEN 'Y' ELSE 'N' END

DECLARE @ExpiredFlag CHAR(1)
SELECT @ExpiredFlag = CASE WHEN @InputCancellationReportType = 'Termination Date' THEN 'Y' ELSE 'N' END

DECLARE @CorporateFlag CHAR(1)
SELECT @CorporateFlag = CASE WHEN @InputMembershipFilter = 'All Memberships' THEN 'N' ELSE 'Y' END

DECLARE @CurrencyCode VARCHAR(15)
SELECT @CurrencyCode = CASE WHEN Count(*) = 1 THEN Min(LocalCurrencyCodes.CurrencyCode) ELSE 'USD' END
  FROM (SELECT DISTINCT ValCurrencyCode.CurrencyCode
          FROM vClub Club
          JOIN #MMSClubIDList
            ON Club.ClubID = #MMSClubIDList.MMSClubID
          JOIN vValCurrencyCode ValCurrencyCode
            ON Club.ValCurrencyCodeID = ValCurrencyCode.ValCurrencyCodeID) LocalCurrencyCodes

SELECT PlanExchangeRate.FromCurrencyCode,
       PlanExchangeRate.PlanExchangeRate ExchangeRate
  INTO #PlanExchangeRate
  FROM vPlanExchangeRate PlanExchangeRate
 WHERE ToCurrencyCode = @CurrencyCode
   AND PlanYear = Year(GetDate())

SELECT Membership.MembershipID,
       Membership.ClubID,
       Membership.ValTerminationReasonID,
       Membership.CancellationRequestDate,
       Membership.ExpirationDate TerminationDate,
       Membership.CompanyID,
       Membership.ValMembershipStatusID,
       Membership.MembershipTypeID,
       Membership.AdvisorEmployeeID,
       Membership.CreatedDateTime
  INTO #Membership
  FROM vMembership Membership
 WHERE ((@CancellationFlag = 'Y'
         AND Membership.CancellationRequestDate >= @InputBeginningDate
         AND Convert(Datetime,Convert(Varchar,Membership.CancellationRequestDate,101),101) <= @InputEndingDate)
     OR (@ExpiredFlag = 'Y'
         AND Membership.ExpirationDate >= @InputBeginningDate
         AND Convert(Datetime,Convert(Varchar,Membership.ExpirationDate,101),101) <= @InputEndingDate))
   AND ((@CorporateFlag = 'Y' AND Membership.CompanyID IS NOT NULL)
     OR (@CorporateFlag = 'N')) 

CREATE INDEX IX_ClubID ON #Membership(ClubID)

SELECT DISTINCT Club.ClubName,
                Member.MemberID PrimaryMemberID,
                Member.FirstName PrimaryMemberFirstName,
                Member.LastName PrimaryMemberLastName,
                '('+MembershipHomePhone.AreaCode+')'+SubString(MembershipHomePhone.Number,1,3)+'-'+SubString(MembershipHomePhone.Number,4,4) HomePhone,
                '('+MembershipWorkPhone.AreaCode+')'+SubString(MembershipWorkPhone.Number,1,3)+'-'+SubString(MembershipWorkPhone.Number,4,4) WorkPhone,
                Member.EmailAddress,
                Cast(MembershipBalance.CurrentBalance * #PlanExchangeRate.ExchangeRate as Decimal(12,2)) AccountBalance,
                CASE WHEN PhoneMembershipCommunicationPreference.ActiveFlag = 1 THEN 'Do Not Phone' ELSE NULL END DoNotPhone,
                CASE WHEN EmailMembershipCommunicationPreference.ActiveFlag = 1 THEN 'Do Not Email' ELSE NULL END DoNotEmail,
                CASE WHEN MailMembershipCommunicationPreference.ActiveFlag = 1 THEN 'Do Not Mail' ELSE NULL END DoNotMail,
                MembershipAddress.AddressLine1 Address1,
                MembershipAddress.AddressLine2 Address2,
                MembershipAddress.City,
                ValState.Description State,
                MembershipAddress.Zip,
                ValCountry.Abbreviation CountryAbbreviation,
                ValRegion.Description Region,
                Club.ClubID,
                #Membership.MembershipID,
                ValMembershipStatus.Description MembershipStatus,
                Replace(Substring(convert(varchar,#Membership.CreatedDateTime,100),1,6)+', '+Substring(convert(varchar,#Membership.CreatedDateTime,100),8,4),'  ',' ') MembershipCreatedDate,
                Replace(Substring(convert(varchar,Member.JoinDate,100),1,6)+', '+Substring(convert(varchar,Member.JoinDate,100),8,4),'  ',' ') MemberJoinDate,
                Replace(Substring(convert(varchar,#Membership.CancellationRequestDate,100),1,6)+', '+Substring(convert(varchar,#Membership.CancellationRequestDate,100),8,4),'  ',' ') CancellationRequestDate,
                Replace(Substring(convert(varchar,#Membership.TerminationDate,100),1,6)+', '+Substring(convert(varchar,#Membership.TerminationDate,100),8,4),'  ',' ') TerminationDate,
                ValTerminationReason.Description CancellationReason,
                Product.ProductID MembershipProductID,
                Product.Description MembershipTypeDescription,
                ValCheckInGroup.Description CheckInGroupDescription,
                ModificationEmployee.EmployeeID ModificationEmployeeID,
                ModificationEmployee.FirstName + ', ' + ModificationEmployee.LastName ModificationEmployee,
                ValCurrencyCode.CurrencyCode LocalCurrencyCode,
                Cast(ISNULL(ClubProduct.Price,0) * #PlanExchangeRate.ExchangeRate as Decimal(12,2)) DuesPrice,
                AdvisorEmployee.LastName + ', ' + AdvisorEmployee.FirstName AdvisorName,
                Company.CorporateCode,
                Company.CompanyName,
                @HeaderDateRange HeaderDateRange,
                @ReportRunDateTime ReportRunDateTime
  FROM #Membership
  JOIN #MMSClubIDList
    ON #Membership.ClubID = #MMSClubIDList.MMSClubID
  JOIN #ValTerminationReasonIDList
    ON Convert(Varchar,#Membership.ValTerminationReasonID) = #ValTerminationReasonIDList.ValTerminationReasonID
    OR #ValTerminationReasonIDList.ValTerminationReasonID = 'All Descriptions'
  JOIN vValTerminationReason ValTerminationReason
    ON #Membership.ValTerminationReasonID = ValTerminationReason.ValTerminationReasonID
  JOIN vValMembershipStatus ValMembershipStatus
    ON #Membership.ValMembershipStatusID = ValMembershipStatus.ValMembershipStatusID
  JOIN vMember Member
    ON #Membership.MembershipID = Member.MembershipID
   AND Member.ValMemberTypeID = 1
  JOIN vClub Club
    ON #Membership.ClubID = Club.ClubID
  JOIN vValRegion ValRegion
    ON Club.ValRegionID = ValRegion.ValRegionID
  JOIN vValCurrencyCode ValCurrencyCode
    ON Club.ValCurrencyCodeID = ValCurrencyCode.ValCurrencyCodeID
  JOIN vMembershipType MembershipType
    ON #Membership.MembershipTypeID = MembershipType.MembershipTypeID
  JOIN vProduct Product
    ON MembershipType.ProductID = Product.ProductID
  JOIN vValCheckInGroup ValCheckInGroup
    ON MembershipType.ValCheckInGroupID = ValCheckInGroup.ValCheckInGroupID
  JOIN vEmployee AdvisorEmployee
    ON #Membership.AdvisorEmployeeID = AdvisorEmployee.EmployeeID
  JOIN vMembershipBalance MembershipBalance
    ON #Membership.MembershipID = MembershipBalance.MembershipID
  LEFT JOIN vClubProduct ClubProduct
    ON Club.ClubID = ClubProduct.ClubID
   AND Product.ProductID = ClubProduct.ProductID
  LEFT JOIN vCompany Company
    ON #Membership.CompanyID = Company.CompanyID
  LEFT JOIN vMembershipPhone MembershipHomePhone
    ON #Membership.MembershipID = MembershipHomePhone.MembershipID
   AND MembershipHomePhone.ValPhoneTypeID = 1
  LEFT JOIN vMembershipPhone MembershipWorkPhone
    ON #Membership.MembershipID = MembershipWorkPhone.MembershipID
   AND MembershipWorkPhone.ValPhoneTypeID = 2
  LEFT JOIN vMembershipCommunicationPreference PhoneMembershipCommunicationPreference
    ON #Membership.MembershipID = PhoneMembershipCommunicationPreference.MembershipID
   AND PhoneMembershipCommunicationPreference.ValCommunicationPreferenceID = 2
  LEFT JOIN vMembershipCommunicationPreference EmailMembershipCommunicationPreference
    ON #Membership.MembershipID = EmailMembershipCommunicationPreference.MembershipID
   AND EmailMembershipCommunicationPreference.ValCommunicationPreferenceID = 3
  LEFT JOIN vMembershipCommunicationPreference MailMembershipCommunicationPreference
    ON #Membership.MembershipID = MailMembershipCommunicationPreference.MembershipID
   AND MailMembershipCommunicationPreference.ValCommunicationPreferenceID = 1
  JOIN vMembershipAddress MembershipAddress
    ON #Membership.MembershipID = MembershipAddress.MembershipID
  LEFT JOIN vValState ValState
    ON MembershipAddress.ValStateID = ValState.ValStateID
  LEFT JOIN vValCountry ValCountry
    ON  MembershipAddress.ValCountryID = ValCountry.ValCountryID
  JOIN #PlanExchangeRate
    ON ValCurrencyCode.CurrencyCode = #PlanExchangeRate.FromCurrencyCode
  LEFT JOIN vMembershipModificationRequest MembershipModificationRequest
    ON #Membership.MembershipID = MembershipModificationRequest.MembershipID
  LEFT JOIN vEmployee ModificationEmployee
    ON MembershipModificationRequest.EmployeeID = ModificationEmployee.EmployeeID
ORDER BY Region, ClubName, CancellationReason, PrimaryMemberLastName, PrimaryMemberFirstName,PrimaryMemberID



END


