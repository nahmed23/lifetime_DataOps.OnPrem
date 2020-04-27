

-- =============================================
--	Object:			mmsCorpUser_CorpFlex
--	Author:			Greg Burdick
--	Create date: 	9/21/2009 per RR396; deploying via dbcr_5046 on 9/23/2009;
--	Description:	retrieves list of members FROM a company and shows which user activity for the supplied time period
--	Modified date:	
-- 
--	EXEC mmsCorpUser_CorpFlex 'Apr 1, 2011', 'Apr 3, 2011', '19|20'
-- =============================================

CREATE   PROC [dbo].[mmsCorpUser_CorpFlex] (
  @StartDate SMALLDATETIME,
  @EndDate SMALLDATETIME,
  @PartnerList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))

CREATE TABLE #Partners (ReimbursementProgramID INT)
IF @PartnerList <> '-99'
	BEGIN
	EXEC procParseIntegerList @PartnerList
	INSERT INTO #Partners (ReimbursementProgramID) SELECT StringField FROM #tmpList
	END
ELSE
	BEGIN
	INSERT INTO #Partners VALUES(-99) 
	END

SELECT MS.CancellationRequestDate, VR.Description AS RegionDescription, 
	C.ClubName,M.MemberID, M.FirstName, M.LastName, M.JoinDate as JoinDate_Sort,
	Replace(SubString(Convert(Varchar, M.JoinDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, M.JoinDate),5,DataLength(Convert(Varchar, M.JoinDate))-12)),' '+Convert(Varchar,Year(M.JoinDate)),', '+Convert(Varchar,Year(M.JoinDate))) as JoinDate, 
	VMS.Description AS MembershipStatusDescription, MS.ExpirationDate, 
	RP.ReimbursementProgramName AS [Partner], RPIF.ReimbursementProgramID,
	P.Description AS ProductDescription, VMT.Description AS MemberTypeDescription, 
	MS.MembershipID, IsNull(MU.UsageDateTime,'Jan 1,1900') AS UsageDateTime
FROM vReimbursementProgram RP
JOIN vMemberReimbursement MR ON RP.ReimbursementProgramID = MR.ReimbursementProgramID
JOIN vReimbursementProgramIdentifierFormat RPIF ON RPIF.ReimbursementProgramIdentifierFormatID = MR.ReimbursementProgramIdentifierFormatID		-- added 9/17/2009 GRB
JOIN #Partners tP ON RPIF.ReimbursementProgramID = tP.ReimbursementProgramID
	OR tP.ReimbursementProgramID = -99
JOIN vMember M ON MR.MemberID = M.MemberID
JOIN vMembership MS ON M.MembershipID = MS.MembershipID
JOIN vMembershipType MST ON MS.MembershipTypeID = MST.MembershipTypeID
JOIN vClub C ON MS.ClubID = C.ClubID
JOIN dbo.vValRegion VR ON VR.ValRegionID=C.ValRegionID
JOIN dbo.vProduct P ON P.ProductID=MST.ProductID
JOIN dbo.vValMembershipStatus VMS ON MS.ValMembershipStatusID=VMS.ValMembershipStatusID
JOIN dbo.vValMemberType VMT ON M.ValMemberTypeID=VMT.ValMemberTypeID
LEFT JOIN dbo.vMemberUsage MU ON MU.memberid = M.memberid 
	AND MU.UsageDateTime BETWEEN @StartDate AND @EndDate
WHERE RPIF.Description = 'Corporate Flex'

DROP TABLE #Partners
DROP TABLE #tmpList

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

