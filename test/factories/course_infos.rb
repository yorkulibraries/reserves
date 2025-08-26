FactoryGirl.define do
  factory :course_info do
    faculty { 'Faculty of Health' }
    faculty_abrev { 'HH' }
    faculty_short { 'Health' }
    period_faculty { 'HH' }
    subject_abrev { 'COOP' }
    subject_abrev2 { 'COOP' }
    subject { 'COOPERATIVE EDUCATION' }
    academic_year { '2025' }
    study_session { 'FW' }
    crs_id { 'HH/COOP 2999   3.00' }
    course_title { 'Preparing for Co-op Work in Health and Health-related Environments' }
    course_title1 { 'Preparing for Co-op Work in Health and Health-rela' }
    course_number { '2999' }
    year_level { '2' }
    credit { 3 }
    section { 'A' }
    instructor_name { nil }
  end
end