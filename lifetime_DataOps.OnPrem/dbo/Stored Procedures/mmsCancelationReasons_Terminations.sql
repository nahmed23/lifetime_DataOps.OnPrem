
/*	=============================================
	Object:			dbo.mmsCancelationReasons_Terminations
	Author:			
	Create date: 	
	Description:	Returns a YTD recordset used in the CancelationReasons Brio document in the qTerminations section
					Returns a recordset containing detail about a list of termination reasons for a list of Clubnames

	Modified date:	2/22/2010 GRB: fix QC#4352; assume time portion with EndDate; deploying via dbcr_5712 on 2/24/2010
					
	EXEC mmsCancelationReasons_Terminations ''
	=============================================	*/

CREATE       PROC [dbo].[mmsCancelationReasons_Terminations] (
	@StartDate SMALLDATETIME,
	@EndDate SMALLDATETIME,
	@ClubIDList VARCHAR(8000),
	@TerminationReasonIDList VARCHAR(8000)
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

SELECT VR.Description RegionDescription, C.ClubName, M.MemberID, M.FirstName, 
     M.LastName, P.Description MembershipTypeDescription, MPH.HomePhoneNumber, 
     MPH.BusinessPhoneNumber, MS.ExpirationDate, MS.CancellationRequestDate, 
     MADDR.AddressLine1, MADDR.AddressLine2, MADDR.City, MADDR.Zip, 
     VTR.Description TerminationReasonDescription, MS.MembershipID, 
     VST.Abbreviation StateAbbreviation, VCO.Abbreviation CountryAbbreviation,
     CO.CorporateCode, M.EmailAddress, VTR.ValTerminationReasonID
--	,@EndDate [AdjEndDate]											-- <validation only> 2/22/2010 GRB

FROM dbo.vMembership MS
JOIN dbo.vMember M
     ON M.MembershipID = MS.MembershipID
JOIN dbo.vClub C
     ON MS.ClubID = C.ClubID
JOIN dbo.vValRegion VR
     ON C.ValRegionID = VR.ValRegionID
JOIN dbo.vValTerminationReason VTR
     ON MS.ValTerminationReasonID = VTR.ValTerminationReasonID
JOIN dbo.vValMemberType VMT
     ON M.ValMemberTypeID = VMT.ValMemberTypeID
JOIN dbo.vMembershipType MT
     ON MS.MembershipTypeID = MT.MembershipTypeID
JOIN dbo.vProduct P
     ON MT.ProductID = P.ProductID
LEFT JOIN dbo.vCompany CO
     ON MS.CompanyID = CO.CompanyID
LEFT JOIN dbo.vMemberPhoneNumbers MPH 
     ON MS.MembershipID = MPH.MembershipID 
--LEFT JOIN dbo.vMembershipAddress MADDR		-- <old code> 2/22/2010 GRB
JOIN dbo.vMembershipAddress MADDR 
     ON MADDR.MembershipID = MS.MembershipID 
LEFT JOIN dbo.vValCountry VCO 
     ON MADDR.ValCountryID = VCO.ValCountryID 
LEFT JOIN dbo.vValState VST 
     ON MADDR.ValStateID = VST.ValStateID
JOIN #Clubs tmpC
     ON C.ClubID = tmpC.ClubID
LEFT JOIN #TermReasonID TR
     ON VTR.ValTerminationReasonID = TR.ReasonID
WHERE 
--	MS.ExpirationDate BETWEEN @StartDate AND @EndDate AND		--<old code> 2/22/2010 GRB
	(MS.ExpirationDate >= @StartDate			-- <new code> 2/22/2010 GRB
	AND MS.ExpirationDate < @AdjEndDate)			-- </new code> 2/22/2010 GRB
	AND VMT.Description = 'Primary' 
	AND C.DisplayUIFlag = 1 AND
     (VTR.Description IS NULL OR
     TR.ReasonID IS NOT NULL)

DROP TABLE #tmpList
DROP TABLE #Clubs
DROP TABLE #TermReasonID

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
