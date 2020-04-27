
-- =============================================
-- Object:			dbo.mmsNPT_Memberships_with_EFT_Updates_via_MyLT
-- Author:			Greg Burdick
-- Create date: 	3/3/2009
-- Description:		
-- Modified date:	
-- Exec mmsNPT_Memberships_with_EFT_Updates_via_MyLT
-- =============================================

CREATE			PROC mmsNPT_Memberships_with_EFT_Updates_via_MyLT

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  DECLARE @CurrentMonthEnd DATETIME
  DECLARE @FirstOfMonth DATETIME

  SET @CurrentMonthEnd = DATEADD(mm,DATEDIFF(mm,-1,GETDATE()),-1)
  SET @FirstOfMonth = CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR, GETDATE(),112),1,6) + '01', 112)

  -- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY
  
SELECT 
	ClubName [Club Name], m.MemberID [Member ID],      
	LastName + ', ' + FirstName [Member Name], 
	p.description [Membership Type], 
	mt.abbreviation [EFT Change Type],  
	msg.OpenDateTime [Open Date], 
	eft.description [Current EFT Option]
	, 
	@FirstOfMonth [@FirstOfMonth], @CurrentMonthEnd [@CurrentMonthEnd], @CurrentMonthEnd + 1 [@CurrentMonthEndPlusOne]
FROM vMembership ship   
	JOIN vMembershipMessage msg ON ship.MembershipID = msg.MembershipID     
	JOIN vvalmembershipmessagetype mt on msg.ValMembershipMessageTypeID = mt.ValMembershipMessageTypeID 
	JOIN vMember m ON ship.MembershipID = m.MembershipID  
	JOIN vProduct p ON ship.MembershipTypeID = p.ProductID      
	JOIN dbo.vValEFTOption eft on ship.ValEFTOptionID = eft.ValEFTOptionID  
	JOIN vClub c ON ship.ClubID = c.ClubID    
WHERE m.MemberID IN (   
      SELECT m.MemberID -- Previous Month's NPTs
      FROM vMembership ship
		  JOIN vMembershipMessage msg ON ship.MembershipID = msg.MembershipID
		  JOIN vMember m ON ship.MembershipID = m.MembershipID
      WHERE ValTerminationReasonID = 24
		  AND CancellationRequestDate >= @FirstOfMonth
		  AND CancellationRequestDate < @FirstOfMonth + 2
		  AND ExpirationDate = @CurrentMonthEnd
		  AND ValMembershipMessageTypeID = 82
		  AND msg.OpenDateTime between @FirstOfMonth AND @FirstOfMonth + 2
		  AND m.ValMemberTypeID = 1
		  AND msg.OpenEmployeeID = -2
		  )
	AND msg.ValMembershipMessageTypeID in (64, 65)  
	AND msg.OpenDateTime >= @FirstOfMonth     
	AND msg.OpenDateTime < @CurrentMonthEnd + 1
	AND msg.OpenEmployeeID = -3   
	AND m.ValMemberTypeID = 1     
ORDER BY m.MemberID, LastName + ', ' + FirstName 

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
