



-- EXEC mmsCorpNewMbShip_NewMembers 'Apr 1, 2011', 'Apr 3, 2011'

--sp to find new corporate memberships

CREATE PROCEDURE [dbo].[mmsCorpNewMbShip_NewMembers]

  @StartDate SMALLDATETIME,
  @EndDate SMALLDATETIME

AS

SET XACT_ABORT ON
SET NOCOUNT ON
BEGIN     

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  SELECT C.ClubName, MS.MembershipID, M.MemberID, M.JoinDate as JoinDate_Sort, 
		 Replace(SubString(Convert(Varchar, M.JoinDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, M.JoinDate),5,DataLength(Convert(Varchar, M.JoinDate))-12)),' '+Convert(Varchar,Year(M.JoinDate)),', '+Convert(Varchar,Year(M.JoinDate))) as JoinDate,
         ER.EmployerName, CO.CorporateCode, CO.CompanyName, 
         VMT.Description AS MemberTypeDescription, 
         M.FirstName AS PrimaryFirstName, M.LastName AS PrimaryLastName, 
         EE.FirstName AS AdvisorFirstName, EE.LastName AS AdvisorLastName, 
         MS.Comments, M.MiddleName AS PrimaryMiddleName, 
         VMMT.Description AS MessageTypeDescription, 
         MSM.Comment AS MembershipMessageComment

    FROM dbo.vValMemberType VMT
    JOIN dbo.vMember M
         ON M.ValMemberTypeID = VMT.ValMemberTypeID
    JOIN dbo.vMembership MS
         ON MS.MembershipID = M.MembershipID   
    JOIN dbo.vEmployee EE
         ON MS.AdvisorEmployeeID = EE.EmployeeID
    JOIN dbo.vClub C
         ON MS.ClubID = C.ClubID  
    LEFT OUTER JOIN dbo.vCompany CO 
         ON MS.CompanyID = CO.CompanyID 
    LEFT OUTER JOIN dbo.vEmployer ER 
         ON M.EmployerID = ER.EmployerID 
    LEFT OUTER JOIN dbo.vMembershipMessage MSM 
         ON M.MembershipID = MSM.MembershipID 
    LEFT OUTER JOIN dbo.vValMembershipMessageType VMMT 
         ON MSM.ValMembershipMessageTypeID = VMMT.ValMembershipMessageTypeID       
   WHERE VMT.Description = 'Primary' AND
         M.JoinDate BETWEEN @StartDate AND @EndDate


-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity   

END

