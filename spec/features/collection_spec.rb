require 'spec_helper'
include CurationConcerns::SearchPathsHelper

describe 'collection' do
  def create_collection(title, description)
    click_link 'Add a Collection'
    fill_in('Title', with: title)
    fill_in('collection_description', with: description)
    click_button('Create Collection')
    expect(page).to have_content 'Items in this Collection'
    expect(page).to have_content title
    expect(page).to have_content description
  end

  let(:title1) { 'Test Collection 1' }
  let(:description1) { 'Description for collection 1 we are testing.' }
  let(:title2) { 'Test Collection 2' }
  let(:description2) { 'Description for collection 2 we are testing.' }

  let(:user) { FactoryGirl.create(:user, email: 'user1@example.com') }
  let(:user_key) { user.user_key }
  let(:generic_works) do
    (0..12).map do |x|
      GenericWork.create!(title: ["title #{x}"]) do |f|
        f.apply_depositor_metadata('user1@example.com')
      end
    end
  end
  let(:gw1) { generic_works[0] }
  let(:gw2) { generic_works[1] }

  before(:all) do
    @old_resque_inline_value = Resque.inline
    Resque.inline = true
  end

  after(:all) do
    Resque.inline = @old_resque_inline_value
    GenericWork.destroy_all
    Collection.destroy_all
  end

  describe 'create collection' do
    before do
      sign_in user
      visit search_path_for_my_collections
    end
    it 'creates a collection' do
      title = 'Genealogies of the American West'
      description = 'All about Genealogies of the American West'
      click_link 'Add a Collection'
      fill_in('Title', with: title)
      fill_in('collection_description', with: description)
      click_button('Create Collection')
      expect(page).to have_content 'Items in this Collection'
      expect(page).to have_content title
      expect(page).to have_content description
    end
    it "fails if there's missing required fields" do
      click_link 'Add a Collection'
      click_button 'Create Collection'
      expect(page).to have_content 'Please review the errors below'
    end
  end

  describe 'delete collection' do
    before do
      @collection = Collection.new title: 'collection title'
      @collection.description = 'collection description'
      @collection.apply_depositor_metadata(user_key)
      @collection.save
      sign_in user
      visit main_app.catalog_index_path('f[generic_type_sim][]' => 'Collection', works: 'mine')
    end

    it 'deletes a collection' do
      expect(page).to have_content(@collection.title)
      within("#document_#{@collection.id}") do
        first('.itemtrash').click
      end
      expect(page).to_not have_content(@collection.title)
      expect(page).to have_content('Collection was successfully deleted.')
    end
  end

  describe 'show collection' do
    before do
      @collection = FactoryGirl.create(:collection, user: user, title: 'collection title', description: 'collection description')
      # @collection = Collection.new title: 'collection title'
      # @collection.description = ['collection description']
      # @collection.apply_depositor_metadata(user_key)
      @collection.members = [gw1, gw2]
      @collection.save
      sign_in user
      visit search_path_for_my_collections
    end

    it 'shows a collection with a listing of Descriptive Metadata and catalog-style search results' do
      expect(page).to have_content(@collection.title)
      within('#document_' + @collection.id) do
        click_link('collection title')
      end
      expect(page).to have_content(@collection.title)
      expect(page).to have_content(@collection.description)
      # Should have search results / contents listing
      expect(page).to have_content(gw1.title.first)
      expect(page).to have_content(gw2.title.first)
      expect(page).to_not have_css('.pager')
    end

    it 'hides collection descriptive metadata when searching a collection' do
      expect(page).to have_content(@collection.title)
      within("#document_#{@collection.id}") do
        click_link('collection title')
      end
      expect(page).to have_content(@collection.title)
      expect(page).to have_content(@collection.description)
      expect(page).to have_content(gw1.title.first)
      expect(page).to have_content(gw2.title.first)
      fill_in('collection_search', with: gw1.title.first)
      click_button('collection_submit')
      # Should not have Collection Descriptive metadata table
      expect(page).to_not have_content('Descriptions')
      expect(page).to have_content(@collection.title)
      expect(page).to have_content(@collection.description)
      # Should have search results / contents listing
      expect(page).to have_content(gw1.title.first)
      expect(page).to_not have_content(gw2.title.first)
      # Should not have Dashboard content in contents listing
      expect(page).to_not have_content('Visibility')
    end
  end

  describe 'edit collection' do
    before do
      @collection = Collection.new(title: 'Awesome Title')
      @collection.description = 'collection description'
      @collection.apply_depositor_metadata(user_key)
      @collection.members = [gw1, gw2]
      @collection.save
      sign_in user
      visit search_path_for_my_collections
    end

    it 'edits and update collection metadata' do
      expect(page).to have_content(@collection.title)
      within("#document_#{@collection.id}") do
        click_link('Edit Collection')
      end
      expect(page).to have_field('collection_title', with: @collection.title)
      expect(page).to have_field('collection_description', with: @collection.description)
      new_title = 'Altered Title'
      new_description = 'Completely new Description text.'
      creators = ['Dorje Trollo', 'Vajrayogini']
      fill_in('Title', with: new_title)
      fill_in('collection_description', with: new_description)
      fill_in('Creator', with: creators.first)
      # within('.form-actions') do
      click_button('Update Collection')
      # end
      expect(page).to_not have_content(@collection.title)
      expect(page).to_not have_content(@collection.description)
      expect(page).to have_content(new_title)
      expect(page).to have_content(new_description)
      expect(page).to have_content(creators.first)
    end

    context "when there are errors" do
      it "displays them" do
        within("#document_#{@collection.id}") do
          click_link('Edit Collection')
        end
        fill_in 'Title', with: ''
        click_button 'Update Collection'
        expect(page).to have_content 'review the errors'
      end
    end

    it 'removes a work from a collection from edit page' do
      expect(page).to have_content(@collection.title)
      within("#document_#{@collection.id}") do
        click_link('Edit Collection')
      end
      expect(page).to have_field('collection_title', with: @collection.title)
      expect(page).to have_field('collection_description', with: @collection.description)
      expect(page).to have_content(gw1.title.first)
      expect(page).to have_content(gw2.title.first)
      within("#document_#{gw1.id}") do
        click_link('Remove From Collection')
      end
      expect(page).to have_content(@collection.title)
      expect(page).to have_content(@collection.description)
      expect(page).to_not have_content(gw1.title.first)
      expect(page).to have_content(gw2.title.first)
    end

    it 'removes a work from a collection from show page' do
      expect(page).to have_content(@collection.title)
      within('#document_' + @collection.id) do
        click_link(@collection.title)
      end
      expect(page).to have_content(gw1.title.first)
      expect(page).to have_content(gw2.title.first)
      within("#document_#{gw1.id}") do
        click_link('Remove From Collection')
      end
      expect(page).to have_content(@collection.title)
      expect(page).to have_content(@collection.description)
      expect(page).to_not have_content(gw1.title.first)
      expect(page).to have_content(gw2.title.first)
    end

    it 'removes all works from a collection' do
      skip 'This is from Sufia, not sure if it should be here.'
      expect(page).to have_content(@collection.title)
      within('#document_' + @collection.id) do
        click_link('Edit Collection')
      end
      expect(page).to have_field('collection_title', with: @collection.title)
      expect(page).to have_field('collection_description', with: @collection.description)
      expect(page).to have_content(gw1.title.first)
      expect(page).to have_content(gw2.title.first)
      first('input#check_all').click
      click_link('Remove From Collection')
      expect(page).to have_content(@collection.title)
      expect(page).to have_content(@collection.description)
      expect(page).to_not have_content(gw1.title.first)
      expect(page).to_not have_content(gw2.title.first)
    end
  end

  describe 'show pages of a collection' do
    before do
      @collection = Collection.new title: 'collection title'
      @collection.description = 'collection description'
      @collection.apply_depositor_metadata(user_key)
      @collection.members = generic_works
      @collection.save!
      sign_in user
      visit search_path_for_my_collections
    end

    it 'shows a collection with a listing of Descriptive Metadata and catalog-style search results' do
      expect(page).to have_content(@collection.title)
      within('#document_' + @collection.id) do
        click_link('collection title')
      end
      expect(page).to have_css('.pager')
    end
  end
end
