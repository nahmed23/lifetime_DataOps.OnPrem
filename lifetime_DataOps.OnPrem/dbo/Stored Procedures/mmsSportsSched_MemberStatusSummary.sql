








--
-- MemberStatusSummary_sport_sched.bqy
--
-- 
--

CREATE      PROC dbo.mmsSportsSched_MemberStatusSummary 
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity int
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY


SELECT MS.MembershipID, C.ClubName, MST.MembershipTypeID,
       VMSS.Description AS MembershipStatusDescr, 
       M.JoinDate, MS.ExpirationDate,
       CP.Price AS DuesPrice, MS.ValMembershipStatusID, M.FirstName,
       M.LastName, M.SSN, 
       VR.Description AS RegionDescription,
       GETDATE() AS ProcessingDateTime, 
       M.MemberID, C.ClubID,
       P.Description AS MembershipTypeDescription
  FROM dbo.vMembership MS
  JOIN dbo.vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vValMemberType VMT
       ON M.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN dbo.vValMembershipStatus VMSS
       ON VMSS.ValMembershipStatusID = MS.ValMembershipStatusID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN dbo.vClubProduct CP 
       ON C.ClubID = CP.ClubID AND
       P.ProductID = CP.ProductID
 WHERE ((P.Description LIKE '%Junior%' OR 
       P.Description LIKE '%Sport%'OR P.Description LIKE '%Elite%') AND
       (NOT (P.Description LIKE '%Employee%' OR 
       P.Description LIKE '%Old Fitness%' OR 
       P.Description LIKE '%Short%' OR 
       P.Description LIKE '%Trade%'))) AND
       (MS.ExpirationDate IS NULL OR 
       MS.ExpirationDate> = DATEADD ( day, -32, Getdate() )) AND
       VMT.Description = 'Primary'

 -- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END









