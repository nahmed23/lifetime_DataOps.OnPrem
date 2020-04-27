
CREATE PROC [dbo].[procCognos_MemberContact] (
   @RegionList VARCHAR(3000),
   @ClubIDList VARCHAR(2000),
   @AgeFrom INT,
   @AgeTo INT,
   @BirthMonth VARCHAR(100)
)

AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON

 
------- Execution sample
-----  Exec procCognos_MemberContact 'All Regions','151',8,15,'Month After Next - 1st-15th'
-------


DECLARE @ReportRunDateTime VARCHAR(21)
DECLARE @StartDate DATETIME 
DECLARE @EndDate DATETIME 
/* REP-4429 : increase the width of the variable *@AdjBirthMonth* from VARCHAR(2) to VARCHAR(100).*/
DECLARE @AdjBirthMonth Varchar(100)

SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')
SET @StartDate = CONVERT(DATE,DATEADD(YY, -(@AgeTo+1), GETDATE()),101)
SET @EndDate = CONVERT(DATE,DATEADD(YY, -@AgeFrom, GETDATE()),101)
SET @AdjBirthMonth= CASE WHEN @BirthMonth in('Month After Next - 1st-15th','Month After Next - 16th-31st') 
                       THEN (SELECT SUBSTRING(CONVERT(VARCHAR(10),DATEADD(month,2,CalendarDate),110),1,2)
					         FROM vReportDimDate
						      WHERE CalendarDate = Cast(GetDate() AS Date))
                       ELSE @BirthMonth
					   END
						

SELECT DISTINCT Club.ClubID 
  INTO #Clubs
  FROM vClub Club
  JOIN fnParsePipeList(@ClubIDList) MMSClubIDList
    ON Convert(Varchar,Club.ClubID) = MMSClubIDList.Item
    OR @ClubIDList like '%All Clubs%'
  JOIN vValRegion Region
    On Club.ValRegionID = Region.ValRegionID
  JOIN fnParsePipeList(@RegionList) RegionList
    ON Region.Description = RegionList.Item
    OR @RegionList like '%All Regions%'

CREATE TABLE #tmpList(StringField VARCHAR(50))
CREATE TABLE #Months (BirthMonth VARCHAR(2))
EXEC procParseStringList @AdjBirthMonth
INSERT INTO #Months (BirthMonth) SELECT StringField FROM #tmpList

CREATE TABLE #MonthsList (MonthValue VARCHAR(2), MonthDescription VARCHAR(10))
INSERT INTO #MonthsList values ('01', 'January'), ('02', 'February'),('03', 'March'),
            ('04', 'April'),('05', 'May'),('06', 'June'),('07', 'July'),('08', 'August'),
            ('09', 'September'),('10', 'October'),('11', 'November'),('12', 'December')


 ---- To create a table of possible returned birthdate days, based on selected @BirthMonth
CREATE TABLE #DatesList (DateValue VARCHAR(2))
INSERT INTO #DatesList (DateValue)
    SELECT SubString(Convert(Varchar(8),DimDateKey),7,2)
	  FROM vReportDimDate
	 WHERE CalendarMonthNumberInYear = 1
	   AND CalendarYear = DatePart(year,Getdate())
	   AND DayNumberInCalendarMonth < 16
	   AND @BirthMonth = 'Month After Next - 1st-15th'
	UNION
	SELECT SubString(Convert(Varchar(8),DimDateKey),7,2)
	  FROM vReportDimDate
	 WHERE CalendarMonthNumberInYear = 1
	   AND CalendarYear = DatePart(year,Getdate())
	   AND DayNumberInCalendarMonth > 15
       AND @BirthMonth ='Month After Next - 16th-31st'
	UNION 
	SELECT SubString(Convert(Varchar(8),DimDateKey),7,2)
	  FROM vReportDimDate
	 WHERE CalendarMonthNumberInYear = 1
	   AND CalendarYear = DatePart(year,Getdate())
       AND @BirthMonth Not In('Month After Next - 1st-15th','Month After Next - 16th-31st') 
	


	   


DECLARE @HeaderClubList AS VARCHAR(8000), @HeaderAgeList AS VARCHAR(20), @HeaderBirthdayMonthsList AS VARCHAR(36)
SET @HeaderClubList = STUFF((SELECT ', ' + C.ClubName
                                       FROM vClub C
                                       JOIN #Clubs tC ON tc.ClubID = c.ClubID       
                                       FOR XML PATH('')),1,1,'') 

SET @HeaderAgeList = CONVERT(VARCHAR(3),@AgeFrom) + ' to ' + CONVERT(VARCHAR(3),@AgeTo)


SET @HeaderBirthdayMonthsList = STUFF((SELECT ', ' + ML.MonthDescription
                                       FROM #Months MO
                                       JOIN #MonthsList ML ON ML.MonthValue = MO.BirthMonth
                                       FOR XML PATH('')),1,1,'') 

SELECT M.MembershipID
, M.MemberID
, M.FirstName
, M.LastName
, M.DOB
, M.Gender
, CONVERT(INT, DATEDIFF(day, M.DOB, GETDATE())/ 365.25) AS Age
, SUBSTRING(CONVERT(VARCHAR(10),M.DOB,110),1,2) AS DOBMonth
, M.EmailAddress AS MemberEmailAddress
, M.ValMemberTypeID
, M2.FirstName AS PrimaryMemberFirstName
, M2.LastName AS PrimaryMemberLastName
, M2.EmailAddress AS PrimaryMemberEmailAddress
INTO #Member
FROM dbo.vMember M
	JOIN dbo.vMember M2
	ON M2.MembershipID = M.MembershipID
	AND M2.ValMemberTypeID = 1
WHERE M.DOB >= @StartDate  
      AND M.DOB <= @EndDate 
      AND SUBSTRING(CONVERT(VARCHAR(10),M.DOB,110),1,2) IN (SELECT BirthMonth FROM #Months) 
	  AND SUBSTRING(CONVERT(VARCHAR(10),M.DOB,110),4,2) IN (SELECT DateValue FROM #DatesList) 
      AND M.ActiveFlag = 1

SELECT tM.MembershipID
, tM.MemberID
, tM.FirstName
, tM.LastName
, tM.DOB
, tM.Gender
, VMSS.Description AS MembershipStatus
, VMT.Description AS MemberTypeDescription
, C.ClubName
, MSA.AddressLine1
, MSA.AddressLine2
, MSA.City
, VS.Abbreviation AS StateAbbreviation
, MSA.Zip
, VC.Abbreviation AS CountryAbbreviation
, tM.Age
, tM.PrimaryMemberFirstName
, tM.PrimaryMemberLastName
, tM.PrimaryMemberEmailAddress
, tM.MemberEmailAddress
, '('+ MP.AreaCode + ')' + SUBSTRING(MP.Number,1,3) + '-' + SUBSTRING(MP.Number,4,4) AS PrimaryPhoneNumber
, tM.DOBMonth
, MAX(CASE WHEN VCP.Description = 'Do Not Solicit Via Mail' THEN VCP.Description ELSE '' END) AS DoNotSolicit_Mail
, MAX(CASE WHEN VCP.Description = 'Do Not Solicit Via Phone' THEN VCP.Description ELSE '' END) AS DoNotSolicit_Phone
, ISNULL(VCPS.Description,'Subscribed') ReportingMemberEmailSolicitationStatus
, ISNULL(PVCPS.Description,'Subscribed') PrimaryMemberEmailSolicitationStatus
, @ReportRunDateTime AS ReportRunDateTime
, @HeaderClubList AS HeaderClubList
, @HeaderAgeList AS HeaderAgeList
, @HeaderBirthdayMonthsList AS HeaderBirthdayMonthsList
  FROM dbo.vClub C
  JOIN dbo.vMembership MS
       ON MS.ClubID = C.ClubID
  JOIN #Clubs tC
       ON C.ClubID = tC.ClubID
  JOIN #Member tM
       ON tM.MembershipID = MS.MembershipID
  LEFT JOIN vEmailAddressStatus EAS
       ON tM.MemberEmailAddress = EAS.EmailAddress
      AND EAS.StatusFromDate <= GetDate()
      AND EAS.StatusThruDate > GetDate()
  LEFT JOIN vValCommunicationPreferenceStatus VCPS
       ON EAS.ValCommunicationPreferenceStatusID = VCPS.ValCommunicationPreferenceStatusID
  JOIN dbo.vMembershipAddress MSA
       ON MS.MembershipID = MSA.MembershipID
  JOIN dbo.vValCountry VC
       ON MSA.ValCountryID = VC.ValCountryID
  JOIN dbo.vValState VS
       ON MSA.ValStateID = VS.ValStateID
  JOIN dbo.vValMembershipStatus VMSS
       ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
  JOIN dbo.vValMemberType VMT
       ON tM.ValMemberTypeID = VMT.ValMemberTypeID
  LEFT JOIN vEmailAddressStatus PEAS --Primary
       ON tM.PrimaryMemberEmailAddress = PEAS.EmailAddress
       AND PEAS.StatusFromDate <= GetDate()
       AND PEAS.StatusThruDate > GetDate()
  LEFT JOIN vValCommunicationPreferenceStatus PVCPS --Primary
       ON PEAS.ValCommunicationPreferenceStatusID = PVCPS.ValCommunicationPreferenceStatusID
  LEFT JOIN dbo.vPrimaryPhone PP
       ON MS.MembershipID = PP.MembershipID
  LEFT JOIN dbo.vMembershipPhone MP
       ON PP.MembershipID = MP.MembershipID
       AND PP.ValPhoneTypeID = MP.ValPhoneTypeID
  LEFT JOIN dbo.vMembershipCommunicationPreference MSCP
       ON MSCP.MembershipID = MS.MembershipID AND
       MSCP.ActiveFlag = 1
  LEFT JOIN dbo.vValCommunicationPreference VCP
       ON MSCP.ValCommunicationPreferenceID = VCP.ValCommunicationPreferenceID       
 WHERE VMSS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended') 
       AND MSA.ValAddressTypeID = 1  
	   AND C.DisplayUIFlag = 1              
GROUP BY tM.MembershipID, tM.MemberID, tM.FirstName, tM.LastName, tM.DOB, tM.Gender
         , VMSS.Description , VMT.Description, C.ClubName, MSA.AddressLine1, MSA.AddressLine2
		 , MSA.City, VS.Abbreviation, MSA.Zip, VC.Abbreviation, tM.Age, tM.PrimaryMemberFirstName
		 , tM.PrimaryMemberLastName, tM.PrimaryMemberEmailAddress, tM.MemberEmailAddress
 	     , '('+ MP.AreaCode + ')' + SUBSTRING(MP.Number,1,3) + '-' + SUBSTRING(MP.Number,4,4) ,tM.DOBMonth
	     , ISNULL(VCPS.Description,'Subscribed'), ISNULL(PVCPS.Description,'Subscribed')

DROP TABLE #Clubs
DROP TABLE #Months
DROP TABLE #tmpList
DROP TABLE #MonthsList
DROP TABLE #Member
DROP TABLE #DatesList

END
