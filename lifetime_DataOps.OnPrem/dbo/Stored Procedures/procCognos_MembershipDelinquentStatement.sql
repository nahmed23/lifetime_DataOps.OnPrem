
CREATE PROC [dbo].[procCognos_MembershipDelinquentStatement] (
@MemberIDList VARCHAR(8000),
@DelinquencyGroup VARCHAR(15),
@RegionList VARCHAR(8000),
@ClubIDList VARCHAR(8000),
@MembershipExpirationDate DATETIME,
@MessageText VARCHAR(255)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON


------
--- EXEC procCognos_MembershipDelinquentStatement '0','61-90 - Dues','Minnesota-MNWest','151','6/30/2015','This is a test message'
------
  



  Declare @ThirtyOneDaysPrior DateTime
  Declare @SixtyOneDaysPrior DateTime
  Declare @NinetyOneDaysPrior DateTime
  Declare @OneHundredTwentyOneDaysPrior DateTime
  
  SET @ThirtyOneDaysPrior = DateAdd(Day,-31,GetDate())
  SET @SixtyOneDaysPrior = DateAdd(Day,-61,GetDate())
  SET @NinetyOneDaysPrior = DateAdd(Day,-91,GetDate())
  SET @OneHundredTwentyOneDaysPrior = DateAdd(Day,-121,GetDate())


CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #MemberIDs (MemberID INT) 

  SELECT DISTINCT Club.ClubID as ClubID
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



IF @DelinquencyGroup = 'NPT'
BEGIN

INSERT INTO #MemberIDs (MemberID)
SELECT M.MemberID
  FROM dbo.vMembership MS
  JOIN dbo.vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN #Clubs CS
       ON MS.ClubID = CS.ClubID
  JOIN dbo.vValTerminationReason VTR 
       ON MS.ValTerminationReasonID = VTR.ValTerminationReasonID
 WHERE MS.ExpirationDate = @MembershipExpirationDate 
   AND M.ValMemberTypeID = 1 
   AND VTR.Description = 'Non-Payment Terms' 

END


ELSE

IF @DelinquencyGroup = '0-30 - Dues' 
BEGIN
INSERT INTO #MemberIDs (MemberID)
Select Zero_Thirty.MemberID
 From (SELECT M.MemberID,Min(MMST.TranDate) EarliestDate
  FROM vMembership MS
  JOIN #Clubs #Clubs
       ON MS.ClubID = #Clubs.ClubID
  JOIN vTranBalance TB
       ON TB.MembershipID = MS.MembershipID
  JOIN vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN vMembershipBalance MSB
       ON MS.MembershipID = MSB.MembershipID
  LEFT JOIN vTranItem TI
       ON TB.TranItemID = TI.TranItemID
  LEFT JOIN vMMSTran MMST
       ON TI.MMSTranID = MMST.MMSTranID

 WHERE TB.TranBalanceAmount > 0 
   AND MSB.CommittedBalance > 0
   AND TB.TranProductCategory = 'Dues'
   AND M.ValMemberTypeID = 1 
   AND (IsNull(MS.ExpirationDate,'1/1/1900')='1/1/1900' or MS.ExpirationDate >= @MembershipExpirationDate)
   Group By M.MemberID) Zero_Thirty
   Where Zero_Thirty.EarliestDate > @ThirtyOneDaysPrior and Zero_Thirty.EarliestDate < GetDate()



END

ELSE

IF @DelinquencyGroup = '31-60 - Dues' 
BEGIN
INSERT INTO #MemberIDs (MemberID)
Select ThirtyOne_Sixty.MemberID
 From (SELECT M.MemberID,Min(MMST.TranDate) EarliestDate
  FROM vMembership MS
  JOIN #Clubs #Clubs
       ON MS.ClubID = #Clubs.ClubID
  JOIN vTranBalance TB
       ON TB.MembershipID = MS.MembershipID
  JOIN vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN vMembershipBalance MSB
       ON MS.MembershipID = MSB.MembershipID
  LEFT JOIN vTranItem TI
       ON TB.TranItemID = TI.TranItemID
  LEFT JOIN vMMSTran MMST
       ON TI.MMSTranID = MMST.MMSTranID

 WHERE TB.TranBalanceAmount > 0 
   AND MSB.CommittedBalance > 0
   AND TB.TranProductCategory = 'Dues'
   AND M.ValMemberTypeID = 1 
   AND (IsNull(MS.ExpirationDate,'1/1/1900')='1/1/1900' or MS.ExpirationDate >= @MembershipExpirationDate)
   Group By M.MemberID) ThirtyOne_Sixty
   Where ThirtyOne_Sixty.EarliestDate > @SixtyOneDaysPrior and ThirtyOne_Sixty.EarliestDate <= @ThirtyOneDaysPrior



END

ELSE

IF @DelinquencyGroup = '61-90 - Dues' 
BEGIN
INSERT INTO #MemberIDs (MemberID)
Select SixtyOne_Ninety.MemberID
 From (SELECT M.MemberID,Min(MMST.TranDate) EarliestDate
  FROM vMembership MS
  JOIN #Clubs #Clubs
       ON MS.ClubID = #Clubs.ClubID
  JOIN vTranBalance TB
       ON TB.MembershipID = MS.MembershipID
  JOIN vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN vMembershipBalance MSB
       ON MS.MembershipID = MSB.MembershipID
  LEFT JOIN vTranItem TI
       ON TB.TranItemID = TI.TranItemID
  LEFT JOIN vMMSTran MMST
       ON TI.MMSTranID = MMST.MMSTranID

 WHERE TB.TranBalanceAmount > 0 
   AND MSB.CommittedBalance > 0
   AND TB.TranProductCategory = 'Dues'
   AND M.ValMemberTypeID = 1 
   AND (IsNull(MS.ExpirationDate,'1/1/1900')='1/1/1900' or MS.ExpirationDate >= @MembershipExpirationDate)
   Group By M.MemberID) SixtyOne_Ninety
   Where SixtyOne_Ninety.EarliestDate > @NinetyOneDaysPrior and SixtyOne_Ninety.EarliestDate <= @SixtyOneDaysPrior



END

ELSE

IF @DelinquencyGroup = '91-120 - Dues' 
BEGIN
INSERT INTO #MemberIDs (MemberID)
Select NinetyOne_OneHundredTwenty.MemberID
 From (SELECT M.MemberID,Min(IsNull(MMST.TranDate,@OneHundredTwentyOneDaysPrior)) EarliestDate
  FROM vMembership MS
  JOIN #Clubs #Clubs
       ON MS.ClubID = #Clubs.ClubID
  JOIN vTranBalance TB
       ON TB.MembershipID = MS.MembershipID
  JOIN vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN vMembershipBalance MSB
       ON MS.MembershipID = MSB.MembershipID
  LEFT JOIN vTranItem TI
       ON TB.TranItemID = TI.TranItemID
  LEFT JOIN vMMSTran MMST
       ON TI.MMSTranID = MMST.MMSTranID

 WHERE TB.TranBalanceAmount > 0 
   AND MSB.CommittedBalance > 0
   AND TB.TranProductCategory = 'Dues'
   AND M.ValMemberTypeID = 1 
   AND (IsNull(MS.ExpirationDate,'1/1/1900')='1/1/1900' or MS.ExpirationDate >= @MembershipExpirationDate)
   Group By M.MemberID) NinetyOne_OneHundredTwenty
   Where NinetyOne_OneHundredTwenty.EarliestDate >  @OneHundredTwentyOneDaysPrior and NinetyOne_OneHundredTwenty.EarliestDate <= @NinetyOneDaysPrior



END

ELSE


IF @DelinquencyGroup = 'Over 120 - Dues' 
BEGIN
INSERT INTO #MemberIDs (MemberID)
Select OverOneHundredTwenty.MemberID
 From (SELECT M.MemberID
  FROM vMembership MS
  JOIN #Clubs #Clubs
       ON MS.ClubID = #Clubs.ClubID
  JOIN vTranBalance TB
       ON TB.MembershipID = MS.MembershipID
  JOIN vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN vMembershipBalance MSB
       ON MS.MembershipID = MSB.MembershipID
  LEFT JOIN vTranItem TI
       ON TB.TranItemID = TI.TranItemID
  LEFT JOIN vMMSTran MMST
       ON TI.MMSTranID = MMST.MMSTranID

 WHERE TB.TranBalanceAmount > 0 
   AND MSB.CommittedBalance > 0
   AND TB.TranProductCategory = 'Dues'
   AND M.ValMemberTypeID = 1 
   AND IsNull(TB.TranItemID,0)=0
   AND (IsNull(MS.ExpirationDate,'1/1/1900')='1/1/1900' or MS.ExpirationDate >= @MembershipExpirationDate)
   Group By M.MemberID) OverOneHundredTwenty



END

ELSE

BEGIN

  EXEC procParseStringList @MemberIDList
  INSERT INTO #MemberIDs (MemberID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList
END 

SELECT MMST.TranDate as TranDate_Sort, 
	   Replace(SubString(Convert(Varchar, MMST.TranDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MMST.TranDate),5,DataLength(Convert(Varchar, MMST.TranDate))-12)),' '+Convert(Varchar,Year(MMST.TranDate)),', '+Convert(Varchar,Year(MMST.TranDate))) as TranDate,
       IsNull(P.Description,'Outstanding Balance') as  ProductDescription, 
	   MMST.MemberID TransactionMemberID, 
	   TB.TranBalanceAmount, 
	   VTT.Description TranTypeDescription,
	   IsNull(VTT.Description,'')+'  -  '+IsNull(P.Description,'Outstanding Balance') as StatementDescriptionLine,
       VR.Description MMSRegionDescription, 
	   C.ClubName, 
	   VMS.Description MembershipStatusDescription,
       MS.ExpirationDate as MembershipExpirationDate,
	   VTR.Description as MembershipTerminationReason,
	   MS.CreatedDateTime,
	   M.MemberID UISelectedMemberID,
       SA.FirstName as StatementFirstName, 
	   SA.LastName as StatementLastName,
	   SA.FirstName+' '+SA.LastName+'  #'+Convert(varchar,M.MemberID) as StatementNameLine, 
	   SA.CompanyName as StatementCompanyName,
	   SA.AddressLine1 as StatementAddressLine1,
       SA.AddressLine2 as StatementAddressLine2, 
	   SA.AddressLine1+'; '+IsNull(SA.AddressLine2,'') as StatementAddressLine,
	   SA.City as StatementCity, 
	   VS.Abbreviation as StatementState,
	   SA.Zip as StatementZip,
       VC.Abbreviation StatementCountry,
	   SA.City+', '+VS.Abbreviation+'   '+SA.Zip as StatementCityStateZipLine,
       CA.AddressLine1 AS ClubAddress1, 
	   CA.AddressLine2 AS ClubAddress2,
	   CA.AddressLine1+'; '+IsNull(CA.AddressLine2,'') as ClubAddressLine,
       CA.City AS ClubCity, 
	   CA.Zip AS ClubZip, 
	   CVS.Abbreviation AS ClubState,
	   CA.City+', '+CVS.Abbreviation+'   '+CA.Zip as ClubCityStateZipLine,
       GETDATE() as RunDate_Sort,
	   Replace(SubString(Convert(Varchar, GETDATE()),1,3)+' '+LTRIM(SubString(Convert(Varchar, GETDATE()),5,DataLength(Convert(Varchar, GETDATE()))-12)),' '+Convert(Varchar,Year(GETDATE())),', '+Convert(Varchar,Year(GETDATE()))) as ReportRunDate,
	   @MessageText as StatementMessage,
	   CASE WHEN @DelinquencyGroup = 'NA'THEN 'Selected Memberships'
			ELSE @DelinquencyGroup 
			END HeaderDelinquencyGroup,
		CASE WHEN @DelinquencyGroup = 'NPT'THEN 'Membership Termination Date set to '+ Cast(@MembershipExpirationDate as varchar(12))
		    WHEN @DelinquencyGroup = 'NA' THEN ' '
			ELSE 'Earliest Membership Termination Date: '+ Cast(@MembershipExpirationDate as varchar(12))
			END HeaderMembershipTerminationDate
  FROM  vMember M
  JOIN #MemberIDs #M
     ON M.MemberID = #M.MemberID
  JOIN vTranBalance TB
     On M.MembershipID = TB.MembershipID
  JOIN  vMembership MS
     ON M.MembershipID = MS.MembershipID 
  JOIN vClub C
     ON MS.ClubID = C.ClubID
  JOIN vValRegion VR
     ON C.ValRegionID = VR.ValRegionID
  JOIN vClubAddress  CA
     ON CA.ClubID = C.ClubID
  JOIN vValState CVS
     ON CA.ValStateID = CVS.ValStateID
  JOIN vStatementAddress SA
     ON MS.MembershipID = SA.MembershipID
  JOIN vValState VS
     ON VS.ValStateID = SA.ValStateID
  JOIN vValCountry VC
     ON VC.ValCountryID = SA.ValCountryID
  JOIN vValMembershipStatus VMS
     ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
  JOIN vMembershipBalance MSB
     ON MS.MembershipID = MSB.MembershipID
  LEFT JOIN vTranItem TI
     ON TB.TranItemID = TI.TranItemID
  LEFT JOIN vMMSTran MMST
     ON TI.MMSTranID = MMST.MMSTranID
  LEFT JOIN vValTranType VTT
     ON VTT.ValTranTypeID = MMST.ValTranTypeID
  LEFT JOIN vProduct P
     ON P.ProductID = TI.ProductID
  LEFT JOIN vValTerminationReason VTR
     ON MS.ValTerminationReasonID =  VTR.ValTerminationReasonID
 WHERE TB.TranBalanceAmount > 0 AND
       MSB.CommittedBalance > 0

	   
       
DROP TABLE #MemberIDs
DROP TABLE #tmpList
DROP TABLE #Clubs

END
