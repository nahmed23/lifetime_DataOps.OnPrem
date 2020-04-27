
CREATE PROCEDURE [dbo].[procEmployeeChanges]
AS

BEGIN
  SET XACT_ABORT ON
  SET NOCOUNT ON

  --SELECT THE LATEST RECORDS OF ALL MODIFIED EMPLOYEES
  -- Get the maximum begin date for each employee
  -- Get the maximum begin date for each employee
  SELECT DISTINCT MAX(ISNULL(EeDateEnd,'JAN 01 2020')) EeDateEnd, EeFlxIDEb
  INTO #T1aa
  FROM EEmploy EE JOIN EBase EB ON EE.EEFlxIDEb = EB.EbFlxID
                  JOIN EmployeeExport EX ON EX.EmployeeNumber = EB.EbClock
  GROUP BY EeFlxIDEb

  SELECT DISTINCT MAX(EeDateBeg) EeDateBeg, EE.EeFlxIDEb
  INTO #T1a
  FROM EEmploy EE JOIN #T1aa T ON EE.EeFlxIDEb = T.EeFlxIDEb
            AND ISNULL(EE.EeDateEnd,'JAN 01 2020') = ISNULL(T.EeDateEnd,'JAN 01 2020')
  GROUP BY EE.EeFlxIDEb

  -- Get the maximum mod date for each begin date for each employee
  SELECT DISTINCT ee.EeFlxIDEb, MAX(ee.EeDateBeg) EeDateBeg, MAX(ee.EeDateMod) EeDateMod
    INTO #T1b
    FROM #T1a t1a
    JOIN EEmploy ee
      ON t1a.EeDateBeg = ee.EeDateBeg
     AND t1a.EeFlxIDEb = ee.EeFlxIDEb
   GROUP BY ee.EeFlxIDEb

  -- Get the max eeflxid for the max mod date & begin date for each employee
  SELECT MAX(ee.EeFlxID) EeFlxID
    INTO #T1
    FROM #t1b T
    JOIN EEmploy EE
      ON EE.EeFlxIDEb = T.EeFlxIDEb
     AND EE.EeDateBeg = T.EeDateBeg
     AND EE.EeDateMod = T.EeDateMod
   GROUP BY EE.EeFlxIDEb


  --SELECT THE LATEST RECORDS OF ALL MODIFIED EMPLOYEES
  -- Get the maximum begin date for each employee
  SELECT DISTINCT MAX(ISNULL(EjDateEnd,'JAN 01 2020')) EjDateEnd, EjFlxIDEb
  INTO #T2aa
  FROM EJob EJ JOIN EBase EB ON EJ.EjFlxIDEb = EB.EbFlxID
               JOIN EmployeeExport EX ON EX.EmployeeNumber = EB.EbClock
  GROUP BY EjFlxIDEb

  SELECT DISTINCT MAX(EjDateBeg) EjDateBeg, EJ.EjFlxIDEb
  INTO #T2a
  FROM EJob EJ JOIN #T2aa T ON EJ.EjFlxIDEb = T.EjFlxIDEb
            AND ISNULL(EJ.EjDateEnd,'JAN 01 2020') = ISNULL(T.EjDateEnd,'JAN 01 2020')
  GROUP BY Ej.EjFlxIDEb

  -- Get the maximum mod date for each begin date for each employee
  SELECT DISTINCT ej.EjFlxIDEb, MAX(ej.EjDateBeg) EjDateBeg, MAX(ej.EjDateMod) EjDateMod
    INTO #T2b
    FROM #T2a t2a
    JOIN EJob ej
      ON t2a.EjDateBeg = ej.EjDateBeg
     AND t2a.EjFlxIDEb = ej.EjFlxIDEb
   WHERE ej.EjDateEnd IS NULL
   GROUP BY ej.EjFlxIDEb

  -- Get the max eeflxid for the max mod date & begin date for each employee
  SELECT MAX(ej.EjFlxID) EjFlxID
    INTO #T2
    FROM #t2b T
    JOIN EJob EJ
      ON EJ.EjFlxIDEb = T.EjFlxIDEb
     AND EJ.EjDateBeg = T.EjDateBeg
     AND EJ.EjDateMod = T.EjDateMod
   GROUP BY EJ.EJFlxIDEb

  SELECT EE.*
  INTO #EEmploy
  FROM EEmploy EE JOIN #T1 T ON EE.EeFlxID = T.EeFlxID

  SELECT EJ.*
  INTO #EJob
  FROM EJob EJ JOIN #T2 T ON EJ.EjFlxID = T.EjFlxID
 
  DROP TABLE #T1
  DROP TABLE #T2
  DROP TABLE #T1a
  DROP TABLE #T2a
  DROP TABLE #T1aa
  DROP TABLE #T2aa
  DROP TABLE #T1b
  DROP TABLE #T2b

  --Find the latest records for Employees in the excluded clubs
  CREATE TABLE #ExcludedEmployees (EjFlxIDEb INT, EjFlxID INT)

  INSERT INTO #ExcludedEmployees
  SELECT EjFlxIDEb, MAX(EjFlxID)
  FROM EJob ej
  JOIN CeridianMMSClub cmc
    ON cmc.CeridianClub = ej.EjDivision
  WHERE cmc.ExcludedClubFlag = 1
  GROUP BY EjFlxIDEb

  --Delete any members from an excluded club
  DELETE FROM EmployeeExport
  WHERE EmployeeNumber IN (SELECT EB.EbClock
						   FROM EBase eb
						   JOIN #ExcludedEmployees ee
							 ON eb.EbFlxID = ee.EjFlxIDEb
						  )

  DROP TABLE #ExcludedEmployees

  --SELECT THE DETAILS of MODIFIED EMPLOYEES
  SELECT EE.EmployeeExportID RecordID,CLT.LTUPositionID OldJobCode,CLT1.LTUPositionID NewJobCode,
         CONVERT(INT,EE.EmployeeNumber) EmployeeNumber,EB.EbFirstName FirstName,
         EB.EbMiddleName MiddleInitial,EB.EbLastName LastName,CMC.MMSClubID ClubID,CONVERT(VARCHAR(10),EP.EeDateLastHire,101) DateOfHire,
         CASE ISNULL(EB.EbClock,'')
         WHEN '' THEN 'Terminated'
         ELSE EP.EeStatus 
         END Status,EJ.EjDepartment DepartmentNumber
  INTO #EmployeeExport
  FROM EmployeeExport EE LEFT JOIN EBase EB ON EE.EmployeeNumber = EB.EbClock
                         LEFT JOIN #EEmploy EP ON EB.EBFlxID = EP.EeFlxIDEB
                         LEFT JOIN #EJob EJ ON EB.EBFlxID = EJ.EjFlxIDEB
                         LEFT JOIN CeridianMMSClub CMC ON CMC.CeridianClub = EJ.EjDivision
                         LEFT JOIN CeridianLTUPosition CLT ON CLT.CeridianJobCode = EE.OldJobCode
                         LEFT JOIN CeridianLTUPosition CLT1 ON CLT1.CeridianJobCode = EJ.EjJobCode

--DELETE WMPLOYEES WHO HAVE INVALID STATUS
  DELETE FROM #EmployeeExport WHERE Status = '(none)'
--UPDATE ALL EMPLOYEES WHO HAVE STATSU OTHER THAN ACTIVE TO TERMINATED.
/*  UPDATE #EmployeeExport
  SET Status = 'Terminated'
  WHERE Status NOT LIKE 'Active' AND Status NOT LIKE 'FMLA' AND Status NOT LIKE 'Leave of Absence'
*/
  SELECT RecordID,OldJobCode,NewJobCode,EmployeeNumber,FirstName,MiddleInitial,LastName,
         ClubID,DateOfHire,Status,DepartmentNumber
  FROM #EmployeeExport
  ORDER BY RecordID

  DROP TABLE #EEmploy
  DROP TABLE #EJob
  DROP TABLE #EmployeeExport
END
