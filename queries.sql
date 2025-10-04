---In this project I:
------Queried and validated large relational healthcare databases.
------Built patient cohorts for chronic disease tracking.
------Conducted root-cause and trend analysis for operations.
------Translate raw data into actionable insights for both clinical decision-making and operational efficiency.

---Author: Tolu | date: 10-03-2025


--Find all the patient's records in the appointments table
SELECT *
FROM dbo.[Appointments]
--Find the patient ID of patients who had an appointment in the pediatrics department
SELECT patient_id, department_name
FROM dbo.[Appointments]
where department_name = 'pediatrics'

--Find out how many days on average the patients spent in the Cardiology department of the hospital
SELECT AVG (Days_in_the_hospital) as average_days_cardiology
FROM dbo.[Hospital Records]
Where department_name = 'Cardiology'
--Compare the average number of days the patients are spending in each department of the hospital
SELECT department_name, Round(AVG (Days_in_the_hospital),2) as average_days_by_department
FROM dbo.[Hospital Records]
Group by department_name 
order by average_days_by_department DESC


--Categorize patients based on their length of stay in the hospital

SELECT patient_id, Days_in_the_hospital,
CASE 
	WHEN Days_in_the_hospital < =3 THEN 'Short'
	WHEN Days_in_the_hospital <=5 THEN 'Medium'
	ELSE 'Long'
END as stay_category
FROM dbo.[Hospital Records]

--Count the number of patients in each stay category created above
WITH category AS ( 
SELECT patient_id, Days_in_the_hospital,
CASE 
	WHEN Days_in_the_hospital < =3 THEN 'Short'
	WHEN Days_in_the_hospital <=5 THEN 'Medium'
	ELSE 'Long'
END as stay_category
FROM dbo.[Hospital Records])
SELECT COUNT(*) AS number_of_patients, stay_category
FROM category
GROUP BY stay_category

--Calculate the difference between the arrival time and appointment time in hours
SELECT DATEDIFF(minute, appointment_time, arrival_time) AS min_diff
FROM dbo.Appointments

--Which patients on the "patients" table were hospitalized and for how many days
SELECT p.patient_id, p.patient_name, Days_in_the_hospital
FROM Healthcare_Database.dbo.[Patients] p
JOIN Healthcare_Database.dbo.[Hospital Records] h ON
p.patient_id= h.patient_id

--Verify who has a hospital record
SELECT p.patient_id, p.patient_name, Days_in_the_hospital
FROM Healthcare_Database.dbo.[Patients] p
LEFT JOIN Healthcare_Database.dbo.[Hospital Records] h ON
p.patient_id= h.patient_id
where Days_in_the_hospital IS NULL

--Flag patients who are at risk due to interaction between their medication and smoking status
SELECT patient_id, 
diagnosis, 
medication_prescribed, 
smoker_status,
CASE
	WHEN smoker_status = 'Y' AND medication_prescribed IN ('Insulin','Metformin','Lisinopril' )
	THEN 'Potential Safety Concern: Smoking and Medication Interactions'
	ELSE 'No Safety Concern Identified'
END  'safety_concern'
FROM Healthcare_Database.dbo.[Outpatient Visits]


--Predict hypertension risk

SELECT patient_id,
patient_name, bmi,
family_history_of_hypertension,
CASE 
	WHEN bmi >= 30  and family_history_of_hypertension = 'Yes' THEN 'high risk'
	WHEN bmi >=25  and family_history_of_hypertension = 'Yes' THEN 'medium risk'
	ELSE 'low risk'
END 'risk category'
FROM Healthcare_Database.dbo.[Hospital Records] 

--Predict the likelihood of hypertension based on patient's age, BMI and family history of hypertension

WITH prediction AS (SELECT p.patient_id,p.date_of_birth,h.bmi,h.family_history_of_hypertension, 
CASE
	WHEN DATEDIFF(year, date_of_birth, GETDATE()) >=50 THEN 1
	ELSE 0
END AS age_category,

CASE 
	WHEN bmi < 18.5   THEN 'underweight'
	WHEN bmi >= 18.5 AND bmi < 25 THEN 'normalweight'
	WHEN bmi >= 25 AND bmi <30 THEN 'overweight'
	ELSE 'obese'
END bmi_category,

CASE
	WHEN family_history_of_hypertension = 'Yes' THEN 1
	ELSE 0
END family_history_category
FROM Healthcare_Database.dbo.[Hospital Records] h JOIN
Healthcare_Database.dbo.Patients p ON
h.patient_id = p.patient_id
WHERE DATEDIFF(year, date_of_birth, GETDATE()) >= 18
)
SELECT patient_id,age_category, bmi_category, family_history_of_hypertension, 
CASE
	WHEN (age_category =1 OR family_history_category = 1) AND bmi_category = 'obese'
	THEN 'High Risk'
	WHEN (age_category =1 OR family_history_category = 1) AND bmi_category = 'overweight'
	THEN 'Medium Risk'
	ELSE 'Low Risk'
END risk_prediction
FROM prediction

---Identify individuals at high risk of diabetes based on smoker status and glucose levels

With diabetes_prediction As (
SELECT ov.patient_id, ov.visit_id, ov.smoker_status, l.result_value,
CASE 
	WHEN smoker_status = 'Y' OR result_value >=126 THEN 'High Risk'
	WHEN smoker_status = 'Y' OR (result_value >=100 AND result_value < 126) THEN 'Medium Risk'
	ELSE 'Low Risk'
END risk_category
FROM Healthcare_Database.dbo.outpatient_visits ov JOIN Healthcare_Database.dbo.lab_results l ON
ov.visit_id = l.visit_id
WHERE l.test_name= 'fasting blood sugar'

)

SELECT  risk_category, Count(*) population_count
FROM diabetes_prediction
Group by risk_category 

--Identify a cohort of patients with chronic diseases, including hypertension, hyperlipidemia, and diabetes within the last year
SELECT patient_id, visit_date, diagnosis
FROM Healthcare_Database.dbo.outpatient_visits
WHERE diagnosis IN ('hypertension', 'hyperlipidemia', 'diabetes') 
AND (visit_date >= DATEADD(year, -1, GETDATE())
AND visit_date  <=GETDATE())

--Examine the demographic characteristics of diabetic patients by gender and age group
With classes AS (
SELECT p.gender,
CASE
	WHEN DATEDIFF(year, date_of_birth,GETDATE()) BETWEEN 18 AND 30 THEN '18-30'
	WHEN DATEDIFF(year, date_of_birth,GETDATE()) BETWEEN 31 AND 50 THEN '31-50'
	WHEN DATEDIFF(year, date_of_birth,GETDATE()) BETWEEN 51 AND 70 THEN '51-70'
	ELSE '71+'
END age_group
FROM Healthcare_Database.dbo.Patients p JOIN Healthcare_Database.dbo.outpatient_visits o 
ON p.patient_id = o.patient_id
WHERE diagnosis = 'diabetes')

SELECT gender, age_group, Count(*) count_by_age
FROM classes
GROUP BY gender, age_group


--Investigate the main reason for diabetic patients to visit the hospital
SELECT reason_for_visit, 
COUNT (*) AS visit_count
FROM Healthcare_Database.dbo.outpatient_visits
WHERE diagnosis = 'diabetes' 
GROUP BY  reason_for_visit
ORDER BY  visit_count DESC

--Distribution of smoker status among diabetic patients by gender
SELECT gender, smoker_status, 
COUNT (*) AS smoking_status
FROM Healthcare_Database.dbo.outpatient_visits o JOIN
Healthcare_Database.dbo.Patients p ON 
o.patient_id = p.patient_id
WHERE diagnosis = 'diabetes' 
GROUP BY  smoker_status, gender

---Relationships between age, gender, medication prescribed and blood sugar control among diabetic patients who had a Fasting Blood Sugar test

SELECT p.patient_id, p.patient_name, p.gender, 
DATEDIFF(year, p.date_of_birth, getdate()) age,
o.medication_prescribed, l.result_value, o.diagnosis AS daibetes_staus

FROM Healthcare_Database.dbo.Patients p JOIN 
Healthcare_Database.dbo.outpatient_visits o
ON p.patient_id = o.patient_id
JOIN Healthcare_Database.dbo.lab_results l ON
o.visit_id = l.visit_id
WHERE o.diagnosis = 'diabetes' AND l.test_name = 'Fasting Blood Sugar'

-- Determine Key Performance Indicator patient wait time
SELECT 
department_name,
AVG(DATEDIFF(minute, arrival_time, admission_time)) AS avg_wait_time,
MIN(DATEDIFF(minute, arrival_time, admission_time)) As min_waiting_time,
MAX(DATEDIFF(minute, arrival_time, admission_time)) As min_waiting_time,
COUNT (*) AS total_appointments
FROM [Healthcare_Database].dbo.Appointments
GROUP BY department_name

- Calculate average wait time for laboratory results 
SELECT ov.visit_id, ov.visit_date, ov.doctor_name,
lr.test_name, lr.test_date,
DATEDIFF(day,ov.visit_date, lr.test_date) AS days_between_visit_and_test
FROM [Healthcare_Database].dbo.outpatient_visits ov JOIN
[Healthcare_Database].dbo.lab_results lr ON 
ov.visit_id = lr.visit_id

--Identifying readmission rate per department
SELECT 
department_name,
COUNT(patient_id) total_patients,
COUNT(CASE WHEN Days_in_the_hospital >1 THEN patient_id END) AS readmitted_patients,
(COUNT(CASE WHEN Days_in_the_hospital >1 THEN patient_id END)*100)/COUNT(patient_id) AS readmission_rate
FROM [Healthcare_Database].[dbo].[Hospital Records]
Group by department_name 

SELECT DATENAME(weekday, appointment_date) as week_day, COUNT(DATENAME(weekday, appointment_date)) As frequency_of_visit_per_week
FROM [Healthcare_Database].[dbo].[Appointments]
GROUP BY
DATENAME(weekday, appointment_date) 
Order by  frequency_of_visit_per_week DESC


