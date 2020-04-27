
CREATE PROC [dbo].[procCognos_QualifiedDuesMembershipReport] (
    @CoPayTransactionStartDate DATETIME,
    @CoPayTransactionEndDate DATETIME,
    @RegionList VARCHAR(8000),
    @ClubIDList VARCHAR(8000)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

Declare @AdjustedCoPayTransactionEndDate  DateTime	
Set @AdjustedCoPayTransactionEndDate = DateAdd(Day,1,@CoPayTransactionEndDate)


  -- SELECTED CLUBS
CREATE TABLE #tmpList (StringField VARCHAR(50))

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
	
	
CREATE TABLE #SilverFitTrans (	
     TransactionClubID INT,	
     MembershipID INT,	
     MemberID INT,	
     PostDateTime DateTime,	
     TransactionType Varchar(50),	
     TransactionEmployeeID INT,	
     ProductID INT,	
     ProductDescription Varchar(50),	
     TransactionItemAmount DECIMAL(14,2),	
     TransactionItemSalesTax DECIMAL(14,2))	
INSERT INTO #SilverFitTrans	
Select MMSTran.ClubID, MMSTran.MembershipID, MMSTran.MemberID,MMSTran.PostDateTime,	
VTT.Description as TransactionType, MMSTran.EmployeeID as TransactionEmployeeID,TI.ProductID,P.Description, TI.ItemAmount, TI.ItemSalesTax 	
from vMMSTran MMSTran	
Join vMembership MS	
On MMSTran.MembershipID = MS.MembershipID	
Join vTranItem TI	
On MMSTran.MMSTranID = TI.MMSTranID	
Join vProduct P	
On TI.ProductID = P.ProductID
Join #Clubs #Club
On MS.ClubID = #Club.ClubID	
Join vMembershipType MT	
On MS.MembershipTypeID = MT.MembershipTypeID	
Join vMembershipTypeAttribute MTA	
On MT.MembershipTypeID = MTA.MembershipTypeID	
Join vValTranType VTT	
On MMSTran.ValTranTypeID = VTT.ValTranTypeID	
Where MTA.ValMembershipTypeAttributeID = 33  -----  Membership Status Summary Group 4 Qualifying Rev  Per Paul L. this is how we identify Silver & Fit  	
And MMSTran.PostDateTime >= @CoPayTransactionStartDate
AND MMSTran.PostDateTime < @AdjustedCoPayTransactionEndDate	
AND TI.ProductID in(11339,11340) 
And MMSTran.TranVoidedID is Null
AND (MS.ExpirationDate >= @AdjustedCoPayTransactionEndDate or IsNull(MS.ExpirationDate,'1/1/2999') = '1/1/2999')
Order by MMSTran.MembershipID	

	
	
CREATE TABLE #SilverFitEnrollmentDates (	
     MemberID INT,	
     EnrollmentDate DateTime)	
	
INSERT INTO #SilverFitEnrollmentDates	
Select MR.MemberID, MR.EnrollmentDate	
From vMemberReimbursement MR	
Where MR.ReimbursementProgramID = 45   --- Silver & Fit reimbursement program	
AND (MR.TerminationDate >= @AdjustedCoPayTransactionEndDate OR MR.TerminationDate is NULL)

	
	
CREATE TABLE #PartnerProgramMembers (MemberID INT, PartnerProgramList VARCHAR(2000))	
	
DECLARE @CursorMemberID INT,	
        @CursorPartnerProgramName VARCHAR(2000),	
        @CurrentMemberID INT	
	
DECLARE PartnerProgram_Cursor CURSOR LOCAL READ_ONLY FOR	
SELECT DISTINCT M.MemberID, RP.ReimbursementProgramName	
From vMember M	
Join vMembership MS	
On M.MembershipID = MS.MembershipID	
Join #Clubs #Club
On MS.ClubID = #Club.ClubID
Join vMembershipType MT	
On MS.MembershipTypeID = MT.MembershipTypeID	
Join vMembershipTypeAttribute MTA	
On MT.MembershipTypeID = MTA.MembershipTypeID	
Join vMemberReimbursement MR	
On M.MemberID = MR.MemberID	
JOIN vReimbursementProgram RP	
  ON MR.ReimbursementProgramID = RP.ReimbursementProgramID	
WHERE MR.EnrollmentDate < @AdjustedCoPayTransactionEndDate	
  AND (MR.TerminationDate >= @AdjustedCoPayTransactionEndDate OR MR.TerminationDate IS NULL)	
  AND MTA.ValMembershipTypeAttributeID = 33	
  AND (MS.ExpirationDate >= @AdjustedCoPayTransactionEndDate or IsNull(MS.ExpirationDate,'1/1/2999') = '1/1/2999')

ORDER BY M.MemberID, RP.ReimbursementProgramName	
	
SET @CurrentMemberID = 0	
	
OPEN PartnerProgram_Cursor	
FETCH NEXT FROM PartnerProgram_Cursor INTO @CursorMemberID, @CursorPartnerProgramName	
WHILE (@@FETCH_STATUS = 0)	
  BEGIN	
    IF @CursorMemberID <> @CurrentMemberID	
      BEGIN	
        INSERT INTO #PartnerProgramMembers (MemberID, PartnerProgramList) VALUES (@CursorMemberID,@CursorPartnerProgramName)	
        SET @CurrentMemberID = @CursorMemberID	
      END	
    ELSE	
      BEGIN	
        UPDATE #PartnerProgramMembers	
        SET PartnerProgramList = PartnerProgramList+', '+@CursorPartnerProgramName	
        WHERE MemberID = @CursorMemberID	
      END	
    FETCH NEXT FROM PartnerProgram_Cursor INTO @CursorMemberID, @CursorPartnerProgramName	
  END	
	
CLOSE PartnerProgram_Cursor	
DEALLOCATE PartnerProgram_Cursor	


	
	
CREATE TABLE #SilverFitMemberData (	
       MembershipClubID INT,	
       MembershipClub  VARCHAR(50),	
       MembershipCorporateCode VARCHAR(50),	
       MembershipID INT, 	
       MembershipCreatedDateTime Datetime,	
       MembershipExpirationDate Datetime,	
       SellingMembershipAdvisor_FirstName VARCHAR(50),	
       SellingMembershipAdvisor_LastName VARCHAR(50),	
       MembershipStatus VARCHAR(50),	
       MembershipType VARCHAR(50),	
       MemberID INT,	
	   DOB DATETIME,
       MemberType VARCHAR(50), 	
       FirstName VARCHAR(50), 	
       LastName VARCHAR(50), 	
       MemberJoinDate Datetime,	
       PartnerProgramList VARCHAR(2000),	
       SilverAndFitEnrollmentDate Datetime, 	
       TransactionPostDateTime Datetime,	
       TransactionEmployeeID INT, 	
       ProductDescription VARCHAR(50),	
       TransactionType VARCHAR(50), 	
       TransactionClubID INT, 	
       TransactionItemAmount  DECIMAL(14,2), 	
       TransactionItemSalesTax   DECIMAL(14,2),	
       ReportRunDateTime  Datetime,	
       TransactionDateRange VARCHAR(100))	
	
	
INSERT INTO #SilverFitMemberData	
Select MS.ClubID as MembershipClubID,	
       C.ClubName as MembershipClub,	
       CO.CorporateCode AS MembershipCorporateCode,	
       MS.MembershipID, 	
       MS.CreatedDateTime As MembershipCreatedDateTime,	
       MS.ExpirationDate AS MembershipExpirationDate,	
       E.FirstName AS SellingMembershipAdvisor_FirstName,	
       E.LastName AS SellingMembershipAdvisor_LastName,	
       VMS.Description as MembershipStatus,	
       P.Description as MembershipType,	
       M.MemberID,	
	   M.DOB,
       VMT.Description as MemberType, 	
       M.FirstName, 	
       M.LastName, 	
       M.JoinDate as MemberJoinDate,	
       #PPM.PartnerProgramList,	
       #SFED.EnrollmentDate as SilverAndFitEnrollmentDate, 	
       #SF.PostDateTime AS TransactionPostDateTime,	
       #SF.TransactionEmployeeID, 	
       #SF.ProductDescription,	
       #SF.TransactionType, 	
       #SF.TransactionClubID, 	
       #SF.TransactionItemAmount, 	
       #SF.TransactionItemSalesTax,	
       GETDATE() as ReportRunDateTime,
	   Replace(Substring(convert(varchar,@CoPayTransactionStartDate,100),1,6)+', '+Substring(convert(varchar,@CoPayTransactionStartDate,100),8,4),'  ',' ')
                       + '  through ' + 
                       Replace(Substring(convert(varchar,@CoPayTransactionEndDate,100),1,6)+', '+Substring(convert(varchar,@CoPayTransactionEndDate,100),8,4),'  ',' ')as TransactionDateRange		
       	
From vMember M	
Join vMembership MS	
On M.MembershipID = MS.MembershipID	
Join vValMembershipStatus VMS	
On MS.ValMembershipStatusID = VMS.ValMembershipStatusID	
Join vValMemberType VMT	
On M.ValMemberTypeID = VMT.ValMemberTypeID	
Join vMembershipType MT	
On MS.MembershipTypeID = MT.MembershipTypeID	
Join vProduct P	
On MT.ProductID = P.ProductID	
Join vMembershipTypeAttribute MTA	
On MT.MembershipTypeID = MTA.MembershipTypeID	
Join vClub C	
On MS.ClubID = C.ClubID	
Join #Clubs #Club
On C.ClubID = #Club.ClubID
Left Join vEmployee E	
On MS.AdvisorEmployeeID = E.EmployeeID	
Left Join #SilverFitTrans #SF	
On M.MemberID = #SF.MemberID	
Left Join vCompany CO	
On MS.CompanyID = CO.CompanyID	
Left Join #PartnerProgramMembers #PPM	
ON M.MemberID = #PPM.MemberID	
LEFT JOIN #SilverFitEnrollmentDates #SFED	
ON M.MemberID = #SFED.MemberID	
Where MTA.ValMembershipTypeAttributeID = 33  -----  Membership Status Summary Group 4 Qualifying Rev  Per Paul L. this is how we identify Silver & Fit 
AND (MS.ExpirationDate >= @AdjustedCoPayTransactionEndDate or IsNull(MS.ExpirationDate,'1/1/2999') = '1/1/2999')
AND M.ValMemberTypeID = 1   ------ return Primary members only
Order by MS.ClubID, MS.MembershipID,VMT.ValMemberTypeID,M.MemberID	
	
	
	
	
SELECT  Distinct #SilverFitMemberData.MembershipClubID,	
       #SilverFitMemberData.MembershipClub,	
       #SilverFitMemberData.MembershipCorporateCode,	
       #SilverFitMemberData.MembershipID, 	
       #SilverFitMemberData.MembershipCreatedDateTime,	
       #SilverFitMemberData.MembershipExpirationDate,	
       #SilverFitMemberData.SellingMembershipAdvisor_FirstName,	
       #SilverFitMemberData.SellingMembershipAdvisor_LastName,	
       #SilverFitMemberData.MembershipStatus,	
       #SilverFitMemberData.MembershipType,	
       #SilverFitMemberData.MemberID,	
	   #SilverFitMemberData.DOB,
       #SilverFitMemberData.MemberType, 	
       #SilverFitMemberData.FirstName, 	
       #SilverFitMemberData.LastName, 	
       #SilverFitMemberData.MemberJoinDate,	
       #SilverFitMemberData.PartnerProgramList,	
       #SilverFitMemberData.SilverAndFitEnrollmentDate, 	
       #SilverFitMemberData.TransactionPostDateTime,	
       #SilverFitMemberData.TransactionEmployeeID, 	
       #SilverFitMemberData.ProductDescription,	
       #SilverFitMemberData.TransactionType, 	
       #SilverFitMemberData.TransactionClubID, 	
       #SilverFitMemberData.TransactionItemAmount, 	
       #SilverFitMemberData.TransactionItemSalesTax,	
       #SilverFitMemberData.ReportRunDateTime,	
       #SilverFitMemberData.TransactionDateRange 

	
  FROM #SilverFitMemberData  #SilverFitMemberData	
    Order by #SilverFitMemberData.MembershipClubID, #SilverFitMemberData.MembershipID,#SilverFitMemberData.MemberType,#SilverFitMemberData.MemberID	
	
	
	
Drop Table #tmpList
Drop Table #Clubs
Drop Table #SilverFitTrans	
Drop Table #PartnerProgramMembers	
Drop Table #SilverFitEnrollmentDates 	
Drop Table #SilverFitMemberData	

END
