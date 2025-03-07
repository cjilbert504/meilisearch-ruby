# frozen_string_literal: true

RSpec.describe 'MeiliSearch::Index - Settings' do
  let(:default_ranking_rules) do
    [
      'words',
      'typo',
      'proximity',
      'attribute',
      'sort',
      'exactness'
    ]
  end
  let(:default_searchable_attributes) { ['*'] }
  let(:default_displayed_attributes) { ['*'] }
  let(:settings_keys) do
    [
      'rankingRules',
      'distinctAttribute',
      'searchableAttributes',
      'displayedAttributes',
      'stopWords',
      'synonyms',
      'filterableAttributes',
      'sortableAttributes'
    ]
  end
  let(:uid) { random_uid }

  context 'On global settings routes' do
    let(:index) { client.index(uid) }

    before { client.create_index!(uid) }

    it 'gets default values of settings' do
      settings = index.settings
      expect(settings).to be_a(Hash)
      expect(settings.keys).to contain_exactly(*settings_keys)
      expect(settings['rankingRules']).to eq(default_ranking_rules)
      expect(settings['distinctAttribute']).to be_nil
      expect(settings['searchableAttributes']).to eq(default_searchable_attributes)
      expect(settings['displayedAttributes']).to eq(default_displayed_attributes)
      expect(settings['stopWords']).to eq([])
      expect(settings['synonyms']).to eq({})
      expect(settings['filterableAttributes']).to eq([])
      expect(settings['sortableAttributes']).to eq([])
    end

    it 'updates multiples settings at the same time' do
      task = index.update_settings(
        rankingRules: ['title:asc', 'typo'],
        distinctAttribute: 'title'
      )
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])
      settings = index.settings
      expect(settings['rankingRules']).to eq(['title:asc', 'typo'])
      expect(settings['distinctAttribute']).to eq('title')
      expect(settings['stopWords']).to be_empty
    end

    it 'updates one setting without reset the others' do
      task = index.update_settings(stopWords: ['the'])
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])
      settings = index.settings
      expect(settings['rankingRules']).to eq(default_ranking_rules)
      expect(settings['distinctAttribute']).to be_nil
      expect(settings['stopWords']).to eq(['the'])
      expect(settings['synonyms']).to be_empty
    end

    it 'resets all settings' do
      task = index.update_settings(
        rankingRules: ['title:asc', 'typo'],
        distinctAttribute: 'title',
        stopWords: ['the', 'a'],
        synonyms: { wow: ['world of warcraft'] }
      )
      client.wait_for_task(task['uid'])

      task = index.reset_settings
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      settings = index.settings
      expect(settings['rankingRules']).to eq(default_ranking_rules)
      expect(settings['distinctAttribute']).to be_nil
      expect(settings['stopWords']).to be_empty
      expect(settings['synonyms']).to be_empty
    end

    context 'with snake_case options' do
      it 'does the request with camelCase attributes' do
        task = index.update_settings(
          ranking_rules: ['typo'],
          distinct_ATTribute: 'title',
          stopWords: ['a']
        )

        client.wait_for_task(task['uid'])
        settings = index.settings

        expect(settings['rankingRules']).to eq(['typo'])
        expect(settings['distinctAttribute']).to eq('title')
        expect(settings['stopWords']).to eq(['a'])
      end
    end
  end

  context 'On ranking-rules sub-routes' do
    let(:index) { client.index(uid) }
    let(:ranking_rules) { ['title:asc', 'words', 'typo'] }
    let(:wrong_ranking_rules) { ['title:asc', 'typos'] }

    before { client.create_index!(uid) }

    it 'gets default values of ranking rules' do
      settings = index.ranking_rules
      expect(settings).to eq(default_ranking_rules)
    end

    it 'updates ranking rules' do
      task = index.update_ranking_rules(ranking_rules)
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])
      expect(index.ranking_rules).to eq(ranking_rules)
    end

    it 'updates ranking rules at null' do
      task = index.update_ranking_rules(ranking_rules)
      client.wait_for_task(task['uid'])

      task = index.update_ranking_rules(nil)
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      expect(index.ranking_rules).to eq(default_ranking_rules)
    end

    it 'fails when updating with wrong ranking rules name' do
      task = index.update_ranking_rules(wrong_ranking_rules)
      client.wait_for_task(task['uid'])

      task = index.task(task['uid'])

      expect(task['type']).to eq('settingsUpdate')
      expect(task.keys).to include('error')
      expect(task['error']['code']).to eq('invalid_ranking_rule')
    end

    it 'resets ranking rules' do
      task = index.update_ranking_rules(ranking_rules)
      client.wait_for_task(task['uid'])

      task = index.reset_ranking_rules
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      expect(index.ranking_rules).to eq(default_ranking_rules)
    end
  end

  context 'On distinct-attribute sub-routes' do
    let(:index) { client.index(uid) }
    let(:distinct_attribute) { 'title' }

    it 'gets default values of distinct attribute' do
      client.create_index!(uid)
      settings = index.distinct_attribute

      expect(settings).to be_nil
    end

    it 'updates distinct attribute' do
      task = index.update_distinct_attribute(distinct_attribute)
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      expect(index.distinct_attribute).to eq(distinct_attribute)
    end

    it 'updates distinct attribute at null' do
      task = index.update_distinct_attribute(distinct_attribute)
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      task = index.update_distinct_attribute(nil)
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      expect(index.distinct_attribute).to be_nil
    end

    it 'resets distinct attribute' do
      task = index.update_distinct_attribute(distinct_attribute)
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      task = index.reset_distinct_attribute
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      expect(index.distinct_attribute).to be_nil
    end
  end

  context 'On searchable-attributes sub-routes' do
    let(:index) { client.index(uid) }
    let(:searchable_attributes) { ['title', 'description'] }

    before { client.create_index!(uid) }

    it 'gets default values of searchable attributes' do
      settings = index.searchable_attributes
      expect(settings).to eq(default_searchable_attributes)
    end

    it 'updates searchable attributes' do
      task = index.update_searchable_attributes(searchable_attributes)
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])
      expect(index.searchable_attributes).to eq(searchable_attributes)
    end

    it 'updates searchable attributes at null' do
      task = index.update_searchable_attributes(searchable_attributes)
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      task = index.update_searchable_attributes(nil)
      expect(task['type']).to eq('settingsUpdate')
      expect(task).to have_key('uid')
      client.wait_for_task(task['uid'])

      expect(index.searchable_attributes).to eq(default_searchable_attributes)
    end

    it 'resets searchable attributes' do
      task = index.update_searchable_attributes(searchable_attributes)
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      task = index.reset_searchable_attributes
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      expect(index.task(task['uid'])['status']).to eq('succeeded')
      expect(index.searchable_attributes).to eq(default_searchable_attributes)
    end
  end

  context 'On displayed-attributes sub-routes' do
    let(:index) { client.index(uid) }
    let(:displayed_attributes) { ['title', 'description'] }

    before { client.create_index!(uid) }

    it 'gets default values of displayed attributes' do
      settings = index.displayed_attributes
      expect(settings).to eq(default_displayed_attributes)
    end

    it 'updates displayed attributes' do
      task = index.update_displayed_attributes(displayed_attributes)
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      expect(index.displayed_attributes).to contain_exactly(*displayed_attributes)
    end

    it 'updates displayed attributes at null' do
      task = index.update_displayed_attributes(displayed_attributes)
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      task = index.update_displayed_attributes(nil)
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      expect(index.displayed_attributes).to eq(default_displayed_attributes)
    end

    it 'resets displayed attributes' do
      task = index.update_displayed_attributes(displayed_attributes)
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      task = index.reset_displayed_attributes
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      expect(index.task(task['uid'])['status']).to eq('succeeded')
      expect(index.displayed_attributes).to eq(default_displayed_attributes)
    end
  end

  context 'On synonyms sub-routes' do
    let(:index) { client.index(uid) }
    let(:synonyms) do
      {
        wow: ['world of warcraft'],
        wolverine: ['xmen', 'logan'],
        logan: ['wolverine', 'xmen']
      }
    end

    before { client.create_index!(uid) }

    it 'gets an empty hash of synonyms by default' do
      settings = index.synonyms
      expect(settings).to be_a(Hash)
      expect(settings).to be_empty
    end

    it 'returns an uid when updating' do
      task = index.update_synonyms(synonyms)
      expect(task).to be_a(Hash)
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])
    end

    it 'gets all the synonyms' do
      update_synonyms(index, synonyms)
      settings = index.synonyms
      expect(settings).to be_a(Hash)
      expect(settings.count).to eq(3)
      expect(settings.keys).to contain_exactly('wow', 'wolverine', 'logan')
      expect(settings['wow']).to be_a(Array)
      expect(settings['wow']).to eq(['world of warcraft'])
    end

    it 'overwrites all synonyms when updating' do
      update_synonyms(index, synonyms)
      update_synonyms(index, hp: ['harry potter'], 'harry potter': ['hp'])
      synonyms = index.synonyms
      expect(synonyms).to be_a(Hash)
      expect(synonyms.count).to eq(2)
      expect(synonyms.keys).to contain_exactly('hp', 'harry potter')
      expect(synonyms['hp']).to be_a(Array)
      expect(synonyms['hp']).to eq(['harry potter'])
    end

    it 'updates synonyms at null' do
      update_synonyms(index, synonyms)

      expect do
        update_synonyms(index, nil)
      end.to(change { index.synonyms.length }.from(3).to(0))
    end

    it 'deletes all the synonyms' do
      update_synonyms(index, synonyms)

      expect do
        task = index.reset_synonyms

        expect(task).to be_a(Hash)
        expect(task).to have_key('uid')
        expect(task['type']).to eq('settingsUpdate')
        client.wait_for_task(task['uid'])

        expect(index.synonyms).to be_a(Hash)
      end.to(change { index.synonyms.length }.from(3).to(0))
    end
  end

  context 'On stop-words sub-routes' do
    let(:index) { client.index(uid) }
    let(:stop_words_array) { ['the', 'of'] }
    let(:stop_words_string) { 'a' }

    before { client.create_index!(uid) }

    it 'gets an empty array when there is no stop-words' do
      settings = index.stop_words
      expect(settings).to be_a(Array)
      expect(settings).to be_empty
    end

    it 'updates stop-words when the body is valid (as an array)' do
      task = index.update_stop_words(stop_words_array)
      expect(task).to be_a(Hash)
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
    end

    it 'gets list of stop-words' do
      task = index.update_stop_words(stop_words_array)
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])
      settings = index.stop_words
      expect(settings).to be_a(Array)
      expect(settings).to contain_exactly(*stop_words_array)
    end

    it 'updates stop-words when the body is valid (as single string)' do
      task = index.update_stop_words(stop_words_string)
      expect(task).to be_a(Hash)
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])
      sw = index.stop_words
      expect(sw).to be_a(Array)
      expect(sw).to contain_exactly(stop_words_string)
    end

    it 'updates stop-words at null' do
      task = index.update_stop_words(stop_words_string)
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      task = index.update_stop_words(nil)
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      expect(index.stop_words).to be_empty
    end

    it 'returns an error when the body is invalid' do
      expect do
        index.update_stop_words(test: 'test')
      end.to raise_bad_request_meilisearch_api_error
    end

    it 'resets stop-words' do
      task = index.update_stop_words(stop_words_string)
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      task = index.reset_stop_words
      expect(task).to be_a(Hash)
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      expect(index.stop_words).to be_a(Array)
      expect(index.stop_words).to be_empty
    end
  end

  context 'On filterable-attributes sub-routes' do
    let(:index) { client.index(uid) }
    let(:filterable_attributes) { ['title', 'description'] }

    before { client.create_index!(uid) }

    it 'gets default values of filterable attributes' do
      settings = index.filterable_attributes
      expect(settings).to be_a(Array)
      expect(settings).to be_empty
    end

    it 'updates filterable attributes' do
      task = index.update_filterable_attributes(filterable_attributes)
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])
      expect(index.filterable_attributes).to contain_exactly(*filterable_attributes)
    end

    it 'updates filterable attributes at null' do
      task = index.update_filterable_attributes(filterable_attributes)
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')

      task = index.update_filterable_attributes(nil)
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      expect(index.filterable_attributes).to be_empty
    end

    it 'resets filterable attributes' do
      task = index.update_filterable_attributes(filterable_attributes)
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')

      task = index.reset_filterable_attributes
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      expect(index.task(task['uid'])['status']).to eq('succeeded')
      expect(index.filterable_attributes).to be_empty
    end
  end

  context 'On sortable-attributes sub-routes' do
    let(:index) { client.index(uid) }
    let(:sortable_attributes) { ['title', 'description'] }

    before { client.create_index!(uid) }

    it 'gets default values of sortable attributes' do
      settings = index.sortable_attributes
      expect(settings).to be_a(Array)
      expect(settings).to be_empty
    end

    it 'updates sortable attributes' do
      task = index.update_sortable_attributes(sortable_attributes)
      expect(task).to have_key('uid')
      client.wait_for_task(task['uid'])
      expect(task['type']).to eq('settingsUpdate')
      expect(index.sortable_attributes).to contain_exactly(*sortable_attributes)
    end

    it 'updates sortable attributes at null' do
      task = index.update_sortable_attributes(sortable_attributes)
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      task = index.update_sortable_attributes(nil)
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      expect(index.sortable_attributes).to be_empty
    end

    it 'resets sortable attributes' do
      task = index.update_sortable_attributes(sortable_attributes)
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      task = index.reset_sortable_attributes
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      expect(index.task(task['uid'])['status']).to eq('succeeded')
      expect(index.sortable_attributes).to be_empty
    end
  end

  context 'Index with primary-key' do
    let(:index) { client.index(uid) }

    before { client.create_index!(uid, primaryKey: 'id') }

    it 'gets the default values of settings' do
      settings = index.settings
      expect(settings).to be_a(Hash)
      expect(settings.keys).to contain_exactly(*settings_keys)
      expect(settings['rankingRules']).to eq(default_ranking_rules)
      expect(settings['distinctAttribute']).to be_nil
      expect(settings['searchableAttributes']).to eq(default_searchable_attributes)
      expect(settings['displayedAttributes']).to eq(default_displayed_attributes)
      expect(settings['stopWords']).to eq([])
      expect(settings['synonyms']).to eq({})
    end

    it 'updates multiples settings at the same time' do
      task = index.update_settings(
        rankingRules: ['title:asc', 'typo'],
        distinctAttribute: 'title'
      )
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])
      settings = index.settings
      expect(settings['rankingRules']).to eq(['title:asc', 'typo'])
      expect(settings['distinctAttribute']).to eq('title')
      expect(settings['stopWords']).to be_empty
    end

    it 'updates one setting without reset the others' do
      task = index.update_settings(stopWords: ['the'])
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])
      settings = index.settings
      expect(settings['rankingRules']).to eq(default_ranking_rules)
      expect(settings['distinctAttribute']).to be_nil
      expect(settings['stopWords']).to eq(['the'])
      expect(settings['synonyms']).to be_empty
    end

    it 'resets all settings' do
      task = index.update_settings(
        rankingRules: ['title:asc', 'typo'],
        distinctAttribute: 'title',
        stopWords: ['the'],
        synonyms: {
          wow: ['world of warcraft']
        }
      )
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      task = index.reset_settings
      expect(task).to have_key('uid')
      expect(task['type']).to eq('settingsUpdate')
      client.wait_for_task(task['uid'])

      settings = index.settings
      expect(settings['rankingRules']).to eq(default_ranking_rules)
      expect(settings['distinctAttribute']).to be_nil
      expect(settings['stopWords']).to be_empty
      expect(settings['synonyms']).to be_empty
    end
  end

  context 'Manipulation of searchable/displayed attributes with the primary-key' do
    let(:index) { client.index(random_uid) }

    it 'does not add document when there is no primary-key' do
      task = index.add_documents(title: 'Test')
      client.wait_for_task(task['uid'])
      task = index.task(task['uid'])
      expect(task.keys).to include('error')
      expect(task['error']['code']).to eq('primary_key_inference_failed')
    end

    it 'adds documents when there is a primary-key' do
      task = index.add_documents(objectId: 1, title: 'Test')
      expect(task).to have_key('uid')
      client.wait_for_task(task['uid'])
      expect(index.documents.count).to eq(1)
    end

    it 'resets searchable/displayed attributes' do
      task = index.update_displayed_attributes(['title', 'description'])
      client.wait_for_task(task['uid'])
      task = index.update_searchable_attributes(['title'])
      expect(task).to have_key('uid')
      client.wait_for_task(task['uid'])

      task = index.reset_displayed_attributes
      expect(task).to have_key('uid')
      client.wait_for_task(task['uid'])
      expect(index.task(task['uid'])['status']).to eq('succeeded')

      task = index.reset_searchable_attributes
      expect(task).to have_key('uid')
      client.wait_for_task(task['uid'])
      expect(index.task(task['uid'])['status']).to eq('succeeded')

      expect(index.displayed_attributes).to eq(['*'])
      expect(index.searchable_attributes).to eq(['*'])
    end
  end

  context 'Aliases' do
    let(:index) { client.index(uid) }

    before { client.create_index!(uid) }

    it 'works with method aliases' do
      expect(index.method(:settings) == index.method(:get_settings)).to be_truthy
      expect(index.method(:ranking_rules) == index.method(:get_ranking_rules)).to be_truthy
      expect(index.method(:distinct_attribute) == index.method(:get_distinct_attribute)).to be_truthy
      expect(index.method(:searchable_attributes) == index.method(:get_searchable_attributes)).to be_truthy
      expect(index.method(:displayed_attributes) == index.method(:get_displayed_attributes)).to be_truthy
      expect(index.method(:synonyms) == index.method(:get_synonyms)).to be_truthy
      expect(index.method(:stop_words) == index.method(:get_stop_words)).to be_truthy
      expect(index.method(:filterable_attributes) == index.method(:get_filterable_attributes)).to be_truthy
    end
  end

  def update_synonyms(index, synonyms)
    task = index.update_synonyms(synonyms)

    client.wait_for_task(task['uid'])
  end
end
