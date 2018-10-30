# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/hash_converter'

def basic_class
  PdfFill::Forms::Va210781.new({})
end

describe PdfFill::Forms::Va210781 do
  let(:form_data) do
    {}
  end
  let(:new_form_class) do
    described_class.new(form_data)
  end
  def class_form_data
    new_form_class.instance_variable_get(:@form_data)
  end
  describe '#merge_fields' do
    it 'should merge the right fields', run_at: '2016-12-31 00:00:00 EDT' do
      expect(described_class.new(get_fixture('pdf_fill/21-0781/simple')).merge_fields).to eq(
        get_fixture('pdf_fill/21-0781/merge_fields')
      )
    end
  end

  # rubocop:disable Metrics/LineLength
  describe '#format_persons_involved' do
    it 'should handle no data' do
      expect(new_form_class.send(:format_persons_involved, {})).to be_nil
    end

    data = {
      'personInvolved' => [{
        'name' => {
          'first' => 'B',
          'middle' => 'B',
          'last' => 'B'
        },
        'rank' => 'R',
        'injuryDeath' => 'K',
        'injuryDeathDate' => '2000-01-01',
        'unitAssigned' => 'abc'
      },
                           {
                             'name' => {
                               'first' => 'B',
                               'middle' => 'B',
                               'last' => 'B'
                             },
                             'rank' => 'R',
                             'injuryDeath' => 'K',
                             'injuryDeathDate' => '2000-01-01',
                             'unitAssigned' => 'abc'
                           }]
    }
    it 'should format data correctly' do
      expect(new_form_class.send(:format_persons_involved, data)).to eq "B B B\nRank: R\nUnit Assigned: abc\nInjury or Death Date: 2000-01-01\nInjury or Death Cause: K\n\nB B B\nRank: R\nUnit Assigned: abc\nInjury or Death Date: 2000-01-01\nInjury or Death Cause: K"
    end
  end

  describe '#format_incident_overflow' do
    it 'should handle no data' do
      expect(new_form_class.send(:format_incident_overflow, {}, 0)).to be_nil
    end

    data = {
      'incidentDescription' => 'Lorem.',
      'medalsCitations' => 'ipsum.'
    }

    it 'should format data correctly' do
      expect(JSON.parse(new_form_class.send(:format_incident_overflow, data, 0).to_json)).to eq(
        'value' => '',
        'extras_value' => "Incident Number: 0\n\nIncident Date: \n\nDates of Unit Assignment: \n\nIncident Location: \n\n\n\nUnit Assignment During Incident: \n\n\n\nDescription of Incident: \n\nLorem.\n\nMedals Or Citations: \n\nipsum.\n\nPersons Involved: \n\n"
      )
    end
  end
  # rubocop:enable Metrics/LineLength

  describe '#resolve_cause_injury_death' do
    it 'should resolve listed cause of death correctly' do
      expect(JSON.parse(new_form_class.send(:resolve_cause_injury_death,
                                            { 'injuryDeath' => 'Killed in Action' }, 0).to_json)).to eq(
                                              'killedInAction0' => true
                                            )
    end

    data = {
      'injuryDeath' => 'Other',
      'injuryDeathOther' => 'Natural Causes'
    }
    it 'should resolve other cause of death correctly' do
      expect(JSON.parse(new_form_class.send(:resolve_cause_injury_death, data, 0).to_json)).to eq(
        'other0' => true,
        'otherText0' => 'Natural Causes'
      )
    end
  end

  describe '#flatten_person_identification' do
    data = {
      'name' => {
        'first' => 'Besty',
        'middle' => 'Bester',
        'last' => 'Besterson'
      },
      'rank' => 'Inc 1 Rank 0'
    }
    it 'should process the identification information correctly' do
      expect(JSON.parse(new_form_class.send(:flatten_person_identification, data, 0).to_json)).to eq(
        'first0' => 'Besty',
        'middleInitial0' => 'B',
        'last0' => 'Besterson',
        'rank0' => 'Inc 1 Rank 0'
      )
    end
  end

  describe '#split_person_unit_assignment' do
    data = {
      'unitAssigned' => 'abcdefghijklm0 opqrstuvwxyz12340 bpqrstuvwxyz12340'
    }
    it 'should split the person_unit_assigment correctly' do
      expect(JSON.parse(new_form_class.send(:split_person_unit_assignment, data, 0).to_json)).to eq(
        'unitAssigned0Row0' => 'abcdefghijklm0',
        'unitAssigned0Row1' => 'opqrstuvwxyz12340',
        'unitAssigned0Row2' => 'bpqrstuvwxyz12340'
      )
    end
  end

  describe '#expand_injury_death_date' do
    data = {
      'injuryDeathDate' => '2000-01-01'
    }
    it 'should expand the injury death date correctly' do
      expect(JSON.parse(new_form_class.send(:expand_injury_death_date, data, 0).to_json)).to eq(
        'injuryDeathDateMonth0' => '01',
        'injuryDeathDateDay0' => '01',
        'injuryDeathDateYear0' => '2000'
      )
    end
  end
end
