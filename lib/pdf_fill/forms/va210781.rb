# frozen_string_literal: true

module PdfFill
  module Forms
    class Va210781 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR


      KEY = {
        'veteranFullName' => {
          'first' => {
            key: 'form1[0].#subform[0].ClaimantsFirstName[0]',
            limit: 12,
            question_num: 1,
            question_suffix: 'A',
            question_text: "VETERAN/BENEFICIARY'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'form1[0].#subform[0].ClaimantsMiddleInitial1[0]'
          },
          'last' => {
            key: 'form1[0].#subform[0].ClaimantsLastName[0]',
            limit: 18,
            question_num: 1,
            question_suffix: 'B',
            question_text: "VETERAN/BENEFICIARY'S LAST NAME"
          }
        },
        'veteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[0].ClaimantsSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[0].ClaimantsSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[0].ClaimantsSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'veteranSocialSecurityNumber1' => {
          'first' => {
            key: 'form1[0].#subform[1].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[1].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[1].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'veteranSocialSecurityNumber2' => {
          'first' => {
            key: 'form1[0].#subform[2].VeteransSocialSecurityNumber_FirstThreeNumbers[1]'
          },
          'second' => {
            key: 'form1[0].#subform[2].VeteransSocialSecurityNumber_SecondTwoNumbers[1]'
          },
          'third' => {
            key: 'form1[0].#subform[2].VeteransSocialSecurityNumber_LastFourNumbers[1]'
          }
        },
        'vaFileNumber' => {
          key: 'form1[0].#subform[0].VAFileNumber[0]'
        },
        'veteranDateOfBirth' => {
          'month' => {
            key: 'form1[0].#subform[0].DOBmonth[0]'
          },
          'day' => {
            key: 'form1[0].#subform[0].DOBday[0]'
          },
          'year' => {
            key: 'form1[0].#subform[0].DOByear[0]'
          }
        },
        'veteranServiceNumber' => {
          key: 'form1[0].#subform[0].VeteransServiceNumber[0]'
        },
        'email' => {
          key: 'form1[0].#subform[0].PreferredEmail[0]'
        },
        'veteranPhone' => {
          key: 'form1[0].#subform[0].PreferredEmail[1]'
        },
        'veteranSecondaryPhone' => {
          key: 'form1[0].#subform[0].PreferredEmail[2]'
        },
        'incident' => {
          limit: 2,
          first_key: 'incidentDescription',
          question_text: 'INCIDENTS',
          question_num: 8,
          'incidentDate' => {
            'month' => {
              key: "incidentDateMonth[#{ITERATOR}]"
            },
            'day' => {
              key: "incidentDateDay[#{ITERATOR}]"
            },
            'year' => {
              key: "incidentDateYear[#{ITERATOR}]"
            }
          },
          'unitAssignedDates' => {
            'fromMonth' => {
              key: "unitAssignmentDateFromMonth[#{ITERATOR}]"
            },
            'fromDay' => {
              key: "unitAssignmentDateFromDay[#{ITERATOR}]"
            },
            'fromYear' => {
              key: "unitAssignmentDateFromYear[#{ITERATOR}]"
            },
            'toMonth' => {
              key: "unitAssignmentDateToMonth[#{ITERATOR}]"
            },
            'toDay' => {
              key: "unitAssignmentDateToDay[#{ITERATOR}]"
            },
            'toYear' => {
              key: "unitAssignmentDateToYear[#{ITERATOR}]"
            }
          },
          'incidentLocation' => {
            question_num: 8,
            limit: 3,
            first_key: 'row0',
            'row0' => {
              key: "incidentLocationFirstRow[#{ITERATOR}]"
            },
            'row1' => {
              key: "incidentLocationSecondRow[#{ITERATOR}]"
            },
            'row2' => {
              key: "incidentLocationThirdRow[#{ITERATOR}]"
            }
          },
          'unitAssigned' => {
            question_num: 8,
            limit: 3,
            'row0' => {
              key: "unitAssignmentFirstRow[#{ITERATOR}]",
              limit: 30
            },
            'row1' => {
              key: "unitAssignmentSecondRow[#{ITERATOR}]",
              limit: 30
            },
            'row2' => {
              key: "unitAssignmentThirdRow[#{ITERATOR}]",
              limit: 30
            }
          },
          'incidentDescription' => {
            key: "incidentDescription[#{ITERATOR}]"
          },
          'medalsCitations' => {
            key: "medalsCitations[#{ITERATOR}]"
          },
          'personInvolved' => {
            limit: 2,
            'name' => {
              'first' => {
              key: 'form1[0].#subform[1].ClaimantsFirstName[1]',
              limit: 12
              },
              'middleInitial' => {
              key: 'form1[0].#subform[1].ClaimantsMiddleInitial1[1]'
              },
              'last' => {
              key: 'form1[0].#subform[1].ClaimantsLastName[1]',
              limit: 18
              }
            },
            'rank' => {
              key: 'form1[0].#subform[1].RANK4B[0]'
            },
            'injuryDeathDate' => {
              'month' => {
                key: 'form1[0].#subform[1].DOBmonth[4]'
              },
              'day' => {
                key: 'form1[0].#subform[1].DOBday[4]'
              },
              'year' => {
                key: 'form1[0].#subform[1].DOByear[4]'
              }
            },

            'injuryDeath' => {
              'checkbox' => {
                'killedinAction' => {
                  key: 'form1[0].#subform[1].KILLEDINACTION4[0]'
                },
                'killedInNonBattle' => {
                  key: 'form1[0].#subform[1].KILLEDNONBATTLE4[0]'
                },
                'woundedInAction' => {
                  key: 'form1[0].#subform[1].WOUNDEDINACTION4[0]'
                },
                'injuredNonBattle' => {
                  key: 'form1[0].#subform[1].INJUREDNONBATTLE4[0]'
                },
                'Other' => {
                  key: 'form1[0].#subform[1].WOUNDEDINACTION4[1]'
                }
              }
            },
            'unitAssigned' => {
              question_num: 8,
              limit: 3,
              'row0' => {
                key: 'form1[0].#subform[1].TextField1[6]',
                limit: 30
              },
              'row1' => {
                key: 'form1[0].#subform[1].TextField1[7]',
                limit: 30
              },
              'row2' => {
                key: 'form1[0].#subform[1].TextField1[8]',
                limit: 30
              }
            }
          }
        },
        'remarks' => {
          key: 'form1[0].#subform[2].REMARKS[0]',
          question_num: 14
        },
        'signature' => {
          key: 'form1[0].#subform[2].Signature[0]'
        },
        'signatureDate' => {
          key: 'form1[0].#subform[2].Date11[0]'
        }
      }.freeze

      def merge_fields
        expand_veteran_full_name
        expand_ssn
        expand_veteran_dob

        expand_signature(@form_data['veteranFullName'])
        @form_data['signature'] = '/es/ ' + @form_data['signature']

        @form_data
      end

      private

      def expand_veteran_full_name
        @form_data['veteranFullName'] = extract_middle_i(@form_data, 'veteranFullName')
      end

      def expand_ssn
        ssn = @form_data['veteranSocialSecurityNumber']
        return if ssn.blank?
        ['', '1', '2'].each do |suffix|
          @form_data["veteranSocialSecurityNumber#{suffix}"] = split_ssn(ssn)
        end
      end

      def expand_veteran_dob
        veteran_date_of_birth = @form_data['veteranDateOfBirth']
        return if veteran_date_of_birth.blank?
        @form_data['veteranDateOfBirth'] = split_date(veteran_date_of_birth)
      end
    end
  end
end


# for enum killed in action stuff
# translate.injury.death(injuryDate)
# switch
# 'Killled in Action'
# case
#
#   return
