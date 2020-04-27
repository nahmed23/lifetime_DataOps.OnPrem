


--
-- Returns recordset of membership types by club
--
-- Parameters: none
--

CREATE    PROC dbo.mmsMembershipTypesAnalysis_ClubSummary
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT VR.Description AS RegionDescription, C.ClubName, P.Description AS MembershipTypeDescription,
       COUNT(DISTINCT(MS.MembershipID))AS MembershipCount, MAX(CP.Price)AS Price,
       COUNT(MS.CompanyID) AS CorporateMembershipCount,
  CASE WHEN P.Description LIKE '%Sport%'
       THEN 1
       ELSE 0
       END SportMembershipFlag,
  CASE WHEN P.Description LIKE '%Fitness%' AND NOT(P.Description LIKE '%Sport%')
       THEN 1
       ELSE 0
       END FitnessMembershipFlag      
  FROM dbo.vClub C
  JOIN dbo.vValRegion VR
       ON VR.ValRegionID=C.ValRegionID
  JOIN dbo.vMembership MS
       ON C.ClubID=MS.ClubID
  JOIN dbo.vMembershipType MST
       ON MST.MembershipTypeID=MS.MembershipTypeID
  JOIN dbo.vValMembershipStatus VMS
       ON MS.ValMembershipStatusID=VMS.ValMembershipStatusID
  JOIN dbo.vProduct P
       ON P.ProductID=MST.ProductID
  JOIN dbo.vClubProduct CP 
       ON P.ProductID=CP.ProductID AND
       MS.ClubID=CP.ClubID
 WHERE VMS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended') AND
       (NOT (P.Description LIKE '%Employee%' OR P.Description LIKE '%Short%'))
 GROUP BY VR.Description, C.ClubName, P.Description

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END


