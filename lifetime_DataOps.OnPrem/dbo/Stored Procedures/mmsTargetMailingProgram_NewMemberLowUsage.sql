
-- =============================================
-- Object:			dbo.mmsTargetMailingProgram_NewMemberLowUsage
-- Version:			v1r1
-- Author:			Greg Burdick
-- Create date: 	2/26/2008
-- Description:		returns Usage counts for memberships showing usage during 
--					a timespan originally used for the TargetMailingProgram Brio bqy
-- 
-- Parameters:		a | separated list of clubnames, A start and end usage date
--
-- Modified date:	2/28/2008 GRB: added condition to filter employee memberships
--                  3/13/2012 BSD: Changed DoNotEmail to new EmailSolicitationStatus
-- Test script(s):	EXEC dbo.mmsTargetMailingProgram_NewMemberLowUsage '151', '29, 59, 89, 119', '6'
--					EXEC dbo.mmsTargetMailingProgram_NewMemberLowUsage '151', '33, 63, 93, 123', '6'
--					EXEC dbo.mmsTargetMailingProgram_NewMemberLowUsage '151', '29|59|89|119', '6'
-- =============================================

CREATE    PROC [dbo].[mmsTargetMailingProgram_NewMemberLowUsage] (
	@ClubIDList VARCHAR(2000), 
	@MembershipAgeValues VARCHAR(20),
--	@AgeAdj INT,
	@UsageValue VARCHAR(2)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField Int)
CREATE TABLE #Clubs (ClubID Int)
   EXEC procParseIntegerList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

DECLARE @AgeAdj AS INT
SET @AgeAdj = 
(CASE 
	WHEN @MembershipAgeValues = '45, 75, 105, 135' THEN 15
	WHEN @MembershipAgeValues = '44, 74, 104, 134' THEN 14
	WHEN @MembershipAgeValues = '43, 73, 103, 133' THEN 13
	WHEN @MembershipAgeValues = '42, 72, 102, 132' THEN 12
	WHEN @MembershipAgeValues = '41, 71, 101, 131' THEN 11
	WHEN @MembershipAgeValues = '40, 70, 100, 130' THEN 10
	WHEN @MembershipAgeValues = '39, 69, 99, 129' THEN 9
	WHEN @MembershipAgeValues = '38, 68, 98, 128' THEN 8
	WHEN @MembershipAgeValues = '37, 67, 97, 127' THEN 7
	WHEN @MembershipAgeValues = '36, 66, 96, 126' THEN 6
	WHEN @MembershipAgeValues = '35, 65,  95,125' THEN 5
	WHEN @MembershipAgeValues = '34, 64, 94, 124' THEN 4
	WHEN @MembershipAgeValues = '33, 63, 93, 123' THEN 3
	WHEN @MembershipAgeValues = '32, 62, 92, 122' THEN 2
	WHEN @MembershipAgeValues = '31, 61, 91, 121' THEN 1
	WHEN @MembershipAgeValues = '30, 60, 90, 120' THEN 0
	WHEN @MembershipAgeValues = '29, 59, 89, 119' THEN -1
	WHEN @MembershipAgeValues = '28, 58, 88, 118' THEN -2
	WHEN @MembershipAgeValues = '27, 57, 87, 117' THEN -3
	WHEN @MembershipAgeValues = '26, 56, 86, 116' THEN -4
	WHEN @MembershipAgeValues = '25, 55, 85, 115' THEN -5
	WHEN @MembershipAgeValues = '24, 54, 84, 114' THEN -6
	WHEN @MembershipAgeValues = '23, 53, 83, 113' THEN -7
	WHEN @MembershipAgeValues = '22, 52, 82, 112' THEN -8
	WHEN @MembershipAgeValues = '21, 51, 81, 111' THEN -9
	WHEN @MembershipAgeValues = '20, 50, 80, 110' THEN -10
	WHEN @MembershipAgeValues = '19, 49, 79, 109' THEN -11
	WHEN @MembershipAgeValues = '18, 48, 78, 108' THEN -12
	WHEN @MembershipAgeValues = '17, 47, 77, 107' THEN -13
	WHEN @MembershipAgeValues = '16, 46, 76, 106' THEN -14
	WHEN @MembershipAgeValues = '15, 45, 75, 105' THEN -15
END)

SELECT M.MemberID, M.MembershipID, 
	M.ValMemberTypeID, M.FirstName, M.LastName, M.JoinDate,
	M.EmailAddress,

	VR.Description Region, C.ClubName Club, 
	MSA.AddressLine1 [Address Line 1], MSA.AddressLine2 [Address Line 2], 
	MSA.City, MSA.Zip, 
	P.Name [Membership Type], VMS.Description [Membership Status],
    MPN.HomePhoneNumber, MPN.BusinessPhoneNumber, 
	C.DisplayUIFlag, P.Description MembershipTypeDescription, 
    VS.Abbreviation StateAbbreviation, VC.Abbreviation CountryAbbreviation, 
    PREF.DoNotMailFlag, PREF.DoNotPhoneFlag, --PREF.DoNotEmailFlag,
    ISNULL(VCPS.Description,'Subscribed') EmailSolicitationStatus,
	DATEDIFF(d, M.JoinDate, GETDATE()) DaysSinceJoin, USG.UsageCount

FROM dbo.vMember M
    LEFT JOIN vEmailAddressStatus EAS
        ON M.EmailAddress = EAS.EmailAddress
       AND EAS.StatusFromDate <= GetDate()
       AND EAS.StatusThruDate > GetDate()
    LEFT JOIN vValCommunicationPreferenceStatus VCPS
        ON EAS.ValCommunicationPreferenceStatusID = VCPS.ValCommunicationPreferenceStatusID
	JOIN dbo.vMembership MS
		ON M.MembershipID = MS.MembershipID
	JOIN dbo.vMembershipType MST
		ON MS.MembershipTypeID = MST.MembershipTypeID
	LEFT JOIN dbo.vMembershipAddress MSA
		ON MS.MembershipID = MSA.MembershipID
	JOIN dbo.vProduct P
		ON MST.ProductID = P.ProductID
	JOIN dbo.vValMembershipStatus VMS
		ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
	LEFT JOIN dbo.vMemberPhoneNumbers MPN
		ON MS.MembershipID = MPN.MembershipID 
	LEFT JOIN dbo.vValCountry VC
		ON MSA.ValCountryID = VC.ValCountryID
	LEFT JOIN dbo.vValState VS
		ON MSA.ValStateID = VS.ValStateID
	JOIN dbo.vClub C
		ON MS.ClubID = C.ClubID
	JOIN #Clubs CS
		ON C.ClubID = CS.ClubID
	JOIN dbo.vValRegion VR
       ON VR.ValRegionID = C.ValRegionID
	LEFT JOIN (
			SELECT M.MemberID,
				COUNT(MU.MemberID) UsageCount
			FROM dbo.vMemberUsage MU
				JOIN dbo.vMember M
					ON MU.MemberID = M.MemberID
				JOIN dbo.vMembership MS
					ON M.MembershipID = MS.MembershipID
				JOIN dbo.vValMembershipStatus VMS
					ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
				JOIN dbo.vClub C
					ON MS.ClubID = C.ClubID
				JOIN #Clubs CS
					ON C.ClubID = CS.ClubID
			 WHERE (
						MU.UsageDateTime >= DATEADD(d, -30, GETDATE()) AND
						MU.UsageDateTime <= GETDATE()
					) AND
				   VMS.Description = 'Active' AND
				   C.DisplayUIFlag = 1 AND
				   M.ActiveFlag = 1 --AND
--					C.ClubID = 151
			 GROUP BY M.MemberID 
			 HAVING COUNT(MU.MemberID) < @UsageValue
		   ) USG
				ON M.MemberID = USG.MemberID

	LEFT JOIN (
			SELECT MCP.MembershipID, MCP.ValCommunicationPreferenceID,
				SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via Mail' THEN 1 
					  ELSE NULL END) DoNotMailFlag,
				SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via Phone' THEN 1 
					  ELSE NULL END) DoNotPhoneFlag--,
				--SUM(CASE WHEN VCP.Description = 'Do Not Solicit Via E-Mail' THEN 1 
				--	  ELSE NULL END) DoNotEmailFlag	
			FROM dbo.vMembershipCommunicationPreference MCP
				JOIN dbo.vValCommunicationPreference VCP
					ON MCP.ValCommunicationPreferenceID = VCP.ValCommunicationPreferenceID
			WHERE MCP.ValCommunicationPreferenceID <> 3 AND
				MCP.ValCommunicationPreferenceID <> 1
			GROUP BY MCP.MembershipID, MCP.ValCommunicationPreferenceID
			) PREF
		   ON MS.MembershipID = PREF.MembershipID
WHERE 
	VMS.Description = 'Active' AND
    C.DisplayUIFlag = 1 AND
    M.ActiveFlag = 1 AND
	M.ValMemberTypeID IN (1,3) AND
	DATEDIFF(d, M.JoinDate, GETDATE()) IN (30 + @AgeAdj, 60 + @AgeAdj, 90 + @AgeAdj, 120 + @AgeAdj) AND
--		the following line returns a non zero number if 'employee' is found; ergo, we only want non-employee memberships listed
	CHARINDEX('employee', P.Description) = 0		--2/28/2008 GRB


ORDER BY M.LastName, M.FirstName

DROP TABLE #Clubs
--DROP TABLE #MembershipAge
DROP TABLE #TmpList

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
