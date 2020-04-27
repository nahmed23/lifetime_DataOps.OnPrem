
--
-- Total Email Memberships for a Club
--
-- Parameters: ClubName
--

CREATE    PROC [dbo].[mmsTotalEmailMemberships_Obsolete] (
  @ClubIDList VARCHAR(2000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(20))
CREATE TABLE #Clubs (ClubID VARCHAR(20))
IF @ClubIDList <> 'All'

BEGIN
  EXEC procParseStringList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END

SELECT VR.Description AS RegionDescription, C.ClubName, M.MembershipID,
       E.FirstName AS AdvisorFirstName, E.LastName AS AdvisorLastName, 
       M.EmailAddress AS MemberEmailAddress,
       M.JoinDate, MS.ActivationDate, MS.AdvisorEmployeeID,
       GetDate() AS QueryDate, MS.CreatedDateTime, 
       P.Description AS MemberTypeDescription,
       
       CASE WHEN DATEDIFF(month,M.JoinDate,GETDATE()) = 0 THEN 1 ELSE 0 
       END AS AccumMTDCount,
       CASE WHEN DATEDIFF(month,M.JoinDate,GETDATE()) = 1 THEN 1 ELSE 0 
       END AS AccumLastMoCount,
       CASE WHEN DATEDIFF(day,M.JoinDate,GETDATE()) <= 6  THEN 1 ELSE 0 
       END AS Accum7DayCount,
       
       CASE WHEN DATEDIFF(month,M.JoinDate,GETDATE()) = 0 AND 
            M.EmailAddress IS NOT NULL THEN 1 ELSE 0 
       END AS AccumEmailCollected_MTD,
       CASE WHEN DATEDIFF(month,M.JoinDate,GETDATE()) = 1 AND 
            M.EmailAddress IS NOT NULL THEN 1 ELSE 0 
       END AS AccumEmailCollectedLastMo,
       CASE WHEN DATEDIFF(day,M.JoinDate,GETDATE()) <= 6  AND 
            M.EmailAddress IS NOT NULL THEN 1 ELSE 0 
       END AS AccumEmailCollected_7Day,     
/*
       CASE WHEN DATEDIFF(month,M.JoinDate,GETDATE()) = 0 AND
            M.EmailAddress IS NOT NULL AND
            MSCP.ValCommunicationPreferenceID IS NOT NULL THEN 1 ELSE 0 
       END AS AccumDoNotSolict_MTD,
       CASE WHEN DATEDIFF(month,M.JoinDate,GETDATE()) = 1 AND
            M.EmailAddress IS NOT NULL AND
            MSCP.ValCommunicationPreferenceID IS NOT NULL THEN 1 ELSE 0 
       END AS AccumDoNotSolictLastMo,
       CASE WHEN DATEDIFF(day,M.JoinDate,GETDATE()) <= 6  AND
            M.EmailAddress IS NOT NULL AND
            MSCP.ValCommunicationPreferenceID IS NOT NULL THEN 1 ELSE 0 
       END AS AccumDoNotSolicit_7Day       
*/
       CASE WHEN DATEDIFF(month,M.JoinDate,GetDate()) = 0 AND ISNULL(VCPS.Description,'Subscribed') <> 'Subscribed' THEN 1 ELSE 0 END AccumDoNotSolict_MTD,
       CASE WHEN DATEDIFF(month,M.JoinDate,GetDate()) = 1 AND ISNULL(VCPS.Description,'Subscribed') <> 'Subscribed' THEN 1 ELSE 0 END AccumDoNotSolictLastMo,
       CASE WHEN DATEDIFF(day,M.JoinDate,GetDate()) = 6 AND ISNULL(VCPS.Description,'Subscribed') <> 'Subscribed' THEN 1 ELSE 0 END AccumDoNotSolicit_7Day,
       ISNULL(VCPS.Description,'Subscribed') EmailSolicitationStatus
  FROM dbo.vMember M
  JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID
  JOIN dbo.vValRegion VR
       ON VR.ValRegionID = C.ValRegionID
  JOIN dbo.vValMemberType VMT
       ON VMT.ValMemberTypeID = M.ValMemberTypeID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN dbo.vValMembershipStatus VMSS
       ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID     
  LEFT JOIN dbo.vEmployee E
       ON (MS.AdvisorEmployeeID = E.EmployeeID)
  LEFT JOIN vEmailAddressStatus EAS
       ON M.EmailAddress = EAS.EmailAddress
      AND EAS.StatusFromDate <= GetDate()
      AND EAS.StatusThruDate > GetDate()
  LEFT JOIN vValCommunicationPreferenceStatus VCPS
       ON EAS.ValCommunicationPreferenceStatusID = VCPS.ValCommunicationPreferenceStatusID
  --LEFT JOIN dbo.vMembershipCommunicationPreference MSCP
  --     ON MSCP.MembershipID = MS.MembershipID AND
  --     MSCP.ValCommunicationPreferenceID IN 
  --     (SELECT VCP.ValCommunicationPreferenceID 
  --        FROM dbo.vValCommunicationPreference VCP
  --       WHERE VCP.Description = 'Do Not Solicit Via E-Mail') 
 WHERE VMT.Description = 'Primary' AND
       M.ActiveFlag = 1 AND
       C.DisplayUIFlag = 1 AND
       (DATEDIFF(month,MS.CreatedDateTime,GetDate()) <= 1)  AND
       (NOT P.Description LIKE '%Employee%')

DROP TABLE #Clubs
DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
