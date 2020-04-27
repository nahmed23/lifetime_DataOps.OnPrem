

CREATE PROCEDURE [dbo].[mmsEmailDiamondCounts]
AS 
BEGIN

/* Diamond Memberships Upgrades, Downgrades and Total Counts */

SET XACT_ABORT ON
SET NOCOUNT    ON

DECLARE @recipients VARCHAR(500)

DECLARE @FileName VARCHAR(50)
DECLARE @subjectline VARCHAR (250)
DECLARE @BodyText VARCHAR(100)

SET @FileName = 'DiamondUpgrade.csv'
SET @subjectline = 'Diamond Upgrade' 
SET @BodyText = 'Diamond Upgrade' 
SET @recipients = 'cschultheis@lifetimefitness.com;SLarson@LifeTimeFitness.com'

EXEC msdb.dbo.sp_send_dbmail 
					 @profile_name = 'sqlsrvcacct'
                    ,@recipients = @recipients
					,@copy_recipients = 'ITDatabase@lifetimefitness.com'
                    ,@subject=@subjectline
                    ,@body = @BodyText
					,@attach_query_result_as_file = 1
					,@query_attachment_filename = @FileName
					,@exclude_query_output = 1
					,@query_result_width = 1000
				    ,@query_result_separator = '	' --tab
                    ,@execute_query_database = 'Report_MMS'
					,@query='
SET ANSI_WARNINGS OFF
SET NOCOUNT ON

CREATE TABLE #T1(CLUBNAME VARCHAR(50),ClubID VARCHAR(50),MembershipLevel VARCHAR(50),Counts INT)
INSERT INTO #T1
SELECT c.ClubName, c.ClubID, ISNULL(conv.MembershipLevel,'''') MembershipLevel, COUNT (DISTINCT conv.MembershipID) Counts
FROM vClub c
LEFT JOIN (

	--Specific data
	SELECT pold.Description OldProduct, pnew.Description NewProduct, c.ClubName, 
           c.ClubID, ma.RowID MembershipID, vmg.Description MembershipLevel,
           ma.ModifiedUser, ma.ModifiedDateTime
	FROM vMembershipAudit ma
	JOIN vMembership ms
	  ON ms.MembershipID = ma.RowID
	JOIN vProduct pnew
	  ON pnew.ProductID = ma.NewValue
	JOIN vProduct pold
	  ON pold.ProductID = ma.OldValue
	JOIN vClub c
	  ON c.ClubID = ms.ClubID
	JOIN vMembershipType mt
	  ON mt.ProductID = pold.ProductID
	JOIN vValMembershipTypeGroup vmg
	  ON vmg.ValMembershipTypeGroupID = mt.ValMembershipTypeGroupID
	WHERE ma.ColumnName = ''MembershipTypeID''
	  AND ma.ModifiedDateTime >= ''2010-09-01 10:00''--Nothing Prior to Diamond Conversion
	  AND pnew.Description LIKE ''%Diamond%'' --New Product is Diamond
	  AND pold.Description NOT LIKE ''%Diamond%'' --Old Product not Diamond
	  AND ma.ModifiedUser <> -2 --Converted by a human
	  AND ISNULL(ms.ExpirationDate,GETDATE()) > ma.ModifiedDateTime --The Membership wasn''t terminated before the modification

) conv
  ON c.ClubID = conv.ClubID
WHERE c.DisplayUIFlag = 1
  AND c.ClubDeActivationDate IS NULL
  AND c.CheckInGroupLevel <> 55
GROUP BY c.ClubName, c.ClubID, conv.MembershipLevel
ORDER BY c.ClubName, conv.MembershipLevel

INSERT INTO #T1
SELECT ''Total:'','''','''',SUM(Counts)
FROM #T1

SELECT ClubName,ClubID,MembershipLevel,Counts
FROM #T1

DROP TABLE #T1
'


SET @subjectline = 'Diamond DownGrade' 
SET @BodyText = 'Diamond DownGrade' 
SET @FileName = 'DiamondDownGrade.csv'

EXEC msdb.dbo.sp_send_dbmail 
					 @profile_name = 'sqlsrvcacct'
                    ,@recipients = @recipients
					,@copy_recipients = 'ITDatabase@lifetimefitness.com'
                    ,@subject=@subjectline
                    ,@body = @BodyText
					,@attach_query_result_as_file = 1
					,@query_attachment_filename = @FileName
					,@exclude_query_output = 1
					,@query_result_width = 1000
				    ,@query_result_separator = '	' --tab
                    ,@execute_query_database = 'Report_MMS'
					,@query='
SET ANSI_WARNINGS OFF
SET NOCOUNT ON

CREATE TABLE #T1(CLUBNAME VARCHAR(50),ClubID VARCHAR(50),MembershipLevel VARCHAR(50),Counts INT)
INSERT INTO #T1
SELECT c.ClubName, c.ClubID, ISNULL(conv.MembershipLevel,'''') MembershipLevel, COUNT (DISTINCT conv.MembershipID) Counts
FROM vClub c
LEFT JOIN (

	--Specific data
	SELECT pold.Description OldProduct, pnew.Description NewProduct, c.ClubName, 
           c.ClubID, ma.RowID MembershipID, vmg.Description MembershipLevel,
           ma.ModifiedUser, ma.ModifiedDateTime
	FROM vMembershipAudit ma
	JOIN vMembership ms
	  ON ms.MembershipID = ma.RowID
	JOIN vProduct pnew
	  ON pnew.ProductID = ma.NewValue
	JOIN vProduct pold
	  ON pold.ProductID = ma.OldValue
	JOIN vClub c
	  ON c.ClubID = ms.ClubID
	JOIN vMembershipType mt
	  ON mt.ProductID = pnew.ProductID
	JOIN vValMembershipTypeGroup vmg
	  ON vmg.ValMembershipTypeGroupID = mt.ValMembershipTypeGroupID
	WHERE ma.ColumnName = ''MembershipTypeID''
	  AND ma.ModifiedDateTime >= ''2010-09-01 10:00''--Nothing Prior to Diamond Conversion
	  AND pold.Description LIKE ''%Diamond%'' --Old Product is Diamond
	  AND pnew.Description NOT LIKE ''%Diamond%'' --New Product not Diamond
	  AND ma.ModifiedUser <> -2 --Converted by a human
	  AND ISNULL(ms.ExpirationDate,GETDATE()) > ma.ModifiedDateTime --The Membership wasn''t terminated before the modification

) conv
  ON c.ClubID = conv.ClubID
WHERE c.DisplayUIFlag = 1
  AND c.ClubDeActivationDate IS NULL
  AND c.CheckInGroupLevel <> 55
GROUP BY c.ClubName, c.ClubID, conv.MembershipLevel
ORDER BY c.ClubName, conv.MembershipLevel

INSERT INTO #T1
SELECT ''Total:'','''','''',SUM(Counts)
FROM #T1

SELECT ClubName,ClubID,MembershipLevel,Counts
FROM #T1

DROP TABLE #T1'

SET @subjectline = 'Diamond Total' 
SET @BodyText = 'Diamond Total' 
SET @FileName = 'DiamondTotal.csv'

EXEC msdb.dbo.sp_send_dbmail 
					 @profile_name = 'sqlsrvcacct'
                    ,@recipients = @recipients
					,@copy_recipients = 'ITDatabase@lifetimefitness.com'
                    ,@subject=@subjectline
                    ,@body = @BodyText
					,@attach_query_result_as_file = 1
					,@query_attachment_filename = @FileName
					,@exclude_query_output = 1
					,@query_result_width = 1000
				    ,@query_result_separator = '	' --tab
                    ,@execute_query_database = 'Report_MMS'
					,@query='
SET ANSI_WARNINGS OFF
SET NOCOUNT ON
CREATE TABLE #T1(CLUBNAME VARCHAR(50),ClubID VARCHAR(50),Counts INT)
INSERT INTO #T1
SELECT c.ClubName, c.ClubID, ISNULL(Counts, 0) Counts
FROM vClub c
LEFT JOIN (

	SELECT ms.ClubID, COUNT(MembershipID) Counts
	FROM vMembership ms
	JOIN vMembershipType mt
	  ON mt.MembershipTypeID = ms.MembershipTypeID
	JOIN vProduct p
	  ON p.ProductID = mt.ProductID
	WHERE p.Description LIKE ''%Diamond%''
	  AND ms.ValMembershipStatusID <> 1 --Active
	GROUP BY ms.ClubID
) conv
  ON c.ClubID = conv.ClubID
WHERE c.DisplayUIFlag = 1
  AND c.ClubDeActivationDate IS NULL
  AND c.CheckInGroupLevel <> 55
ORDER BY c.ClubName

INSERT INTO #T1
SELECT ''Total:'','''',SUM(Counts)
FROM #T1

SELECT ClubName,ClubID,Counts
FROM #T1

DROP TABLE #T1'

END
