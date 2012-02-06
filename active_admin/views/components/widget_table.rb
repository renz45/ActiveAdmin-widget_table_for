module ActiveAdmin

  # added the destroy action to the resource_controller so we could
  # redirect back to the page where this table is located, instead of
  # going to the resource index
  class ResourceController
    def destroy(options={}, &block)
      super do |success, failure|
        block.call(success, failure) if block
        success.html { redirect_to :back }
        failure.html { redirect_to :back}
      end
    end
    alias :destroy! :destroy
    protected :destroy!
  end

  module Views
    # This is a rebuilt version of table_for that looks like an index page table.
    # Pagination and column sorting works in the same way, columns can be used the exact
    # same way as in the index page. The collection needs to be a collection of 
    # ActiveRecord relations, so User.all won't work, since
    # that returns an array.

    # widget tables are floated left, so setting a width (a percent is recommended) will make
    # tables stack up against each other

    # example usage:

    # widget_table_for Course, width: '30%' do
    #   column :id
    #   column :title 
    #   column :created_at
    # end

    # widget_table_for User.find(1).courses, width: '30%' do
    #   column :id
    #   column :title 
    #   column :created_at
    # end

    class WidgetTableFor < ::ActiveAdmin::Views::TableFor
      builder_method :widget_table_for

      def build(collection, options = {})
        @options = options
        set_option_defaults
        
        deserialize_widget_params params
        @collection = build_collection(collection)
        
        super(@collection, @options)
      end

      # works the same as the index page default options. The one thing that
      # you need to be aware of is that the resource used in the widget_table
      # needs to be registered with active admin, which means making it's own
      # admin template. Just set the menu option to none if you don't want it 
      # in any of the menus.
      
      def default_actions(options = {})
        options = {
            name: ""
        }.merge(options)
        column options[:name] do |c|
          div do
            links = ''.html_safe
            if controller.action_methods.include?('show')
              links += link_to I18n.t('active_admin.view'), "../#{c.class.to_s.downcase.pluralize}/#{c.id}", class: "member_link view_link"
            end
            if controller.action_methods.include?('edit')
              links += link_to I18n.t('active_admin.edit'), "../#{c.class.to_s.downcase.pluralize}/#{c.id}/edit", class: "member_link edit_link"
            end
            if controller.action_methods.include?('destroy')
              links += link_to I18n.t('active_admin.delete'), "../#{c.class.to_s.downcase.pluralize}/#{c.id}", method: :delete, confirm: I18n.t('active_admin.delete_confirmation'), class: "member_link delete_link"
            end
            links
          end
        end
      end

      protected

      def set_option_defaults
        @options[:class] ||= ''
        @options[:class] << ' index_table widget_table'
        @options[:sortable] ||= true
        @options[:per_page] ||= 10
        @options[:style] = 'float: left; margin-left:25px;'
        @options[:style] << "width: #{@options[:width]};" if @options[:width]
      end

      def build_collection(collection)
        paginated_collection = collection.page(@decoded_params[:page])
                           .per(@options[:per_page])
                           .order("#{@decoded_params[:sort_key]} #{@decoded_params[:order]}")

        set_total_count(collection)
        set_max_page
        paginated_collection
      end

      def set_total_count collection
        @total_count = collection.count
      end

      def set_max_page
        @max_page = (Float(@total_count) / Float(@options[:per_page])).ceil 
      end

      def build_table
        build_pagination_info
        build_table_head
        build_table_body

        build_table_pagination
      end

      def build_pagination_info
        thead do
          td colspan: 200, style: 'text-align: left;'do
            div class: 'pagination_information' do
              "Displaying #{@model.to_s.pluralize} <b>#{@decoded_params[:page]} - #{@max_page}</b> of <b>#{@total_count}</b> in total".html_safe
            end
          end
        end
      end

      def build_sortable_header_for(title, sort_key)
        classes = Arbre::HTML::ClassList.new(["sortable"])
        if @decoded_params[:sort_key] == sort_key
          classes << "sorted-#{@decoded_params[:order]}"
        end
        
        header_class = title.downcase.underscore
        
        classes << header_class

        th class: classes do
          link_to(title, params.merge(param_key => widget_params_sort(sort_key)))
        end
      end

      def widget_params_sort(sort_item)
        
        if @decoded_params[:order] == 'desc'
          order = 'asc'
        else
          order = 'desc'
        end

        serialize_widget_params sort_key: sort_item, page: 1, order: order
      end

      def widget_params_page(page)
        serialize_widget_params page: page
      end

      def param_key
        @param_key ||= "#{@model.to_s}-w".downcase.to_sym 
      end

      def serialize_widget_params(args={})
        args[:sort_key] ||= @decoded_params[:sort_key]
        args[:order] ||= @decoded_params[:order]
        args[:page] ||= @decoded_params[:page]

        "#{args[:sort_key]}-#{args[:order]}-#{args[:page]}"
      end

      def deserialize_widget_params(args)
        @decoded_params = {}
        if args[param_key]
          params_arr = args[param_key].split('-')
        else
          params_arr = []
        end

        @decoded_params[:sort_key] = params_arr[0] || 'created_at'
        @decoded_params[:order] = params_arr[1] || 'desc'
        @decoded_params[:page] = params_arr[2] || '1'
      end

      # this is ugly, but 'span class: 'someclass' {}'  just didn't want to cooporate
      def build_table_pagination
        tfoot do
          td colspan: 200 do
            div class: 'index_footer', style: 'text-align:right;' do
              nav class: 'pagination' do

                html = ''

                if @decoded_params[:page].to_i > 1
                  html << "<span class='first'>#{link_to('&laquo; First'.html_safe, params.merge(param_key => widget_params_page(1)))}</span>"
                  html << " <span class='prev'> #{link_to('&lsaquo; Prev'.html_safe, params.merge(param_key => widget_params_page(prev_page)))}</span>"
                end

                page_button_count.times do |n|
                  t = n + page_number_offset

                  if @decoded_params[:page] == t.to_s
                    html << "<span class='page current'>#{t} </span>"
                  else
                    html << "<span class='page'>#{link_to(t,params.merge(param_key => widget_params_page(t)))}</span>"
                  end
                end

                if @decoded_params[:page].to_i < @max_page
                  html << " <span class='next'>#{link_to('Next &rsaquo;'.html_safe, params.merge(param_key => widget_params_page(next_page)))}</span>"
                  html << "<span class='last'>#{link_to('Last &raquo;'.html_safe, params.merge(param_key => widget_params_page(@max_page)))}</span>"
                end
                html.html_safe
              end
            end
          end
        end
      end

      def page_number_offset
        if @decoded_params[:page].to_i >= @max_page - 2
          @decoded_params[:page].to_i - 4 + (@max_page - @decoded_params[:page].to_i)
        elsif @decoded_params[:page].to_i <= 2
          1
        else
          @decoded_params[:page].to_i - 2
        end
      end

      def page_button_count
        if @max_page > 5
          5
        elsif @max_page > 1
          @max_page
        else
          0
        end
      end

      def next_page
        page = @decoded_params[:page].to_i
        page + 1 unless page == @max_page
      end

      def prev_page
        page = @decoded_params[:page].to_i
        page - 1 unless page == 1
      end

    end #WidgetTableFor

  end
end