
/*	=============================================
	Object:			dbo.mmsCancelationReasons_Cancellations
	Author:			
	Create date: 	
	Description:	Returns a YTD recordset used in the CancelationReasons Brio document in the qSummaryByTermDate section
	Modified date:	2/22/2010 GRB: fix QC#4352; assume time portion with EndDate; deploying via dbcr_5712 on 2/24/2010
					
	EXEC mmsCancelationReasons_Cancellations ''
	=============================================	*/

CREATE      PROC [dbo].[mmsCancelationReasons_Cancellations] (
	@StartDate SMALLDATETIME,
	@EndDate SMALLDATETIME,
	@ClubIDList VARCHAR(1000),
	@TerminationReasonIDList VARCHAR(1000)
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON


-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

DECLARE @AdjEndDate DATETIME							--2/22/2010 GRB
SET @AdjEndDate = DATEADD(day, 1, @EndDate)				--2/22/2010 GRB

CREATE TABLE #tmpList (StringField VARCHAR(50))

-- Parse the ClubIDs into a temp table
EXEC procParseIntegerList @ClubIDList
CREATE TABLE #Clubs (ClubID VARCHAR(50))
INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

-- Parse the TermReasons into a temp table
EXEC procParseIntegerList @TerminationReasonIDList
CREATE TABLE #TermReasonID (ReasonID VARCHAR(50))
INSERT INTO #TermReasonID (ReasonID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

SELECT C.ClubName, M.MemberID, M.FirstName, M.LastName, MPH.HomePhoneNumber, 
     MPH.BusinessPhoneNumber, MS.ExpirationDate, P.Description ProductDescription,
     MS.CancellationRequestDate, R.Description RegionDescription, MADDR.AddressLine1,
     MADDR.AddressLine2, MADDR.City, MADDR.Zip, VTR.Description CancelReasonDescription,
     MS.MembershipID, ST.Abbreviation StateAbbreviation, CNTRY.Abbreviation CountryAbbreviation,
     CO.CorporateCode, M.EmailAddress, VTR.ValTerminationReasonID
--	,@AdjEndDate [AdjEndDate]											-- <validation only> 2/22/2010 GRB
FROM dbo.vMembership MS
JOIN dbo.vValTerminationReason VTR
     ON MS.ValTerminationReasonID = VTR.ValTerminationReasonID
JOIN dbo.vClub C
     ON MS.ClubID = C.ClubID
JOIN dbo.vMember M
     ON M.MembershipID = MS.MembershipID
JOIN dbo.vValMemberType VMT
     ON M.ValMemberTypeID = VMT.ValMemberTypeID
JOIN dbo.vMemberPhoneNumbers MPH
     ON MS.MembershipID = MPH.MembershipID
JOIN dbo.vMembershipType MT
     ON MS.MembershipTypeID = MT.MembershipTypeID
JOIN dbo.vProduct P
     ON MT.ProductID = P.ProductID
JOIN dbo.vValRegion R
     ON C.ValRegionID = R.ValRegionID
JOIN dbo.vMembershipAddress MADDR
     ON MS.MembershipID = MADDR.MembershipID
JOIN dbo.vValState ST
     ON MADDR.ValStateID = ST.ValStateID
JOIN dbo.vValCountry CNTRY 
     ON MADDR.ValCountryID = CNTRY.ValCountryID
LEFT JOIN dbo.vCompany CO
     ON MS.CompanyID = CO.CompanyID
JOIN #Clubs tC
     ON C.ClubID = tC.ClubID
JOIN #TermReasonID TR
     ON VTR.ValTerminationReasonID = TR.ReasonID
WHERE 
--	MS.CancellationRequestDate BETWEEN @StartDate AND @EndDate AND	-- <old code> 2/22/2010 GRB
	(MS.CancellationRequestDate >= @StartDate		-- <new code> 2/22/2010 GRB
	AND MS.CancellationRequestDate < @AdjEndDate)			-- </new code> 2/22/2010 GRB
	AND VMT.Description = 'Primary' 
	AND C.DisplayUIFlag = 1

DROP TABLE #tmpList
DROP TABLE #Clubs
DROP TABLE #TermReasonID

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
