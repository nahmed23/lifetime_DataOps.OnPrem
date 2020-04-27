
CREATE   PROC [dbo].[mmsMemberstatussummary_scheduled_MemberCounts] 
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- returns Member counts by type for the scheduled member status summary report file
-- Parameters: Hard coded for scheduled job to return all clubs' info

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

--LFF ACQUISITION CHANGES BEGIN
SELECT ms.MembershipID,
	CASE WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 160 THEN 220 --Cary
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 159 THEN 219 --Dublin
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 40 THEN 218  --Easton
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 30 THEN 214  --Indianapolis
		 ELSE ms.ClubID END ClubID,
	ms.MembershipTypeID,
	ms.ValMembershipStatusID
INTO #Membership
FROM vMembership ms WITH (NOLOCK)
LEFT JOIN vMembershipTypeAttribute mta WITH (NOLOCK)
  ON mta.MembershipTypeID = ms.MembershipTypeID
 AND mta.ValMembershipTypeAttributeID = 28 --Acquisition
--LFF ACQUISITION CHANGES END 

SELECT C.ClubName, 
       P.Description ProductDescription, 
       Count (M.MemberID) MemberID,
       M.ValMemberTypeID, 
       P.ProductID, 
       C.ClubID
  FROM dbo.vMember M
  JOIN #Membership MS  -- lff change
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN dbo.vValMembershipStatus VMS
       ON VMS.ValMembershipStatusID = MS.ValMembershipStatusID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P 
       ON MST.ProductID = P.ProductID
 WHERE VMS.Description IN ('Active', 'Non-Paid', 'Pending Termination') AND
       M.ActiveFlag = 1
GROUP BY C.ClubName, P.Description, M.ValMemberTypeID, P.ProductID, C.ClubID

drop table #membership

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
