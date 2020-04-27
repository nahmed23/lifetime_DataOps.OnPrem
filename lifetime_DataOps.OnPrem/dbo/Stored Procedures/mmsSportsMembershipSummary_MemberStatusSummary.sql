









--
-- returns Member status info for the SportsMemberstatussummary Brio bqy
--
-- 
--

CREATE     PROC dbo.mmsSportsMembershipSummary_MemberStatusSummary 
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT MS.MembershipID, C.ClubName, MST.MembershipTypeID,
       VMSS.Description AS MembershipStatusDescr, 
       M.JoinDate, MS.ExpirationDate,
       CP.Price AS DuesPrice, MS.ValMembershipStatusID, 
       M.FirstName, M.LastName, M.SSN,
       VR.Description AS RegionDescription,
       GETDATE() AS ProcessingDateTime, M.MemberID, C.ClubID,
       MS.CreatedDateTime, C.DomainNamePrefix, 
       P2.Description AS MembershipTypeDescription
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
  JOIN dbo.vMembershipType MST2
       ON MST2.MembershipTypeID = MS.MembershipTypeID
  JOIN dbo.vProduct P2 
       ON MST2.ProductID = P2.ProductID
 WHERE VMT.Description = 'Primary' AND
       C.DisplayUIFlag = 1 AND
       (MS.ExpirationDate IS NULL OR MS.ExpirationDate> = DATEADD ( day, -33, Getdate() )) AND
       (P2.Description LIKE '%Junior%' OR P2.Description LIKE '%Sport%') AND
       (NOT (P2.Description LIKE '%Employee%' OR
       P2.Description LIKE '%Old Fitness%' OR
       P2.Description LIKE '%Short%' OR
       P2.Description LIKE '%Trade%'))


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END










