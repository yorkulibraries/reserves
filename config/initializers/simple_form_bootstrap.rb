# frozen_string_literal: true

# Use this setup block to configure all options available in SimpleForm.

inputs = %w[
  CollectionSelectInput
  DateTimeInput
  FileInput
  GroupedCollectionSelectInput
  NumericInput
  PasswordInput
  RangeInput
  StringInput
  TextInput
]

inputs.each do |input_type|
  superclass = "SimpleForm::Inputs::#{input_type}".constantize

  new_class = Class.new(superclass) do
    def input_html_classes
      super.push('form-control')
    end
  end

  Object.const_set(input_type, new_class)
end

# Use this setup block to configure all options available in SimpleForm.
SimpleForm.setup do |config|
  config.boolean_style = :nested

  config.wrappers :bootstrap3, tag: 'div', class: 'form-group', error_class: 'has-error',
                               defaults: { input_html: { class: 'default_class' } } do |b|
    b.use :html5
    b.use :min_max
    b.use :maxlength
    b.use :placeholder

    b.optional :pattern
    b.optional :readonly

    b.use :label_input
    b.use :hint,  wrap_with: { tag: 'span', class: 'help-block' }
    b.use :error, wrap_with: { tag: 'span', class: 'help-block has-error' }
  end

  config.wrappers :prepend, tag: 'div', class: 'form-group', error_class: 'has-error' do |b|
    b.use :html5
    b.use :placeholder
    b.wrapper tag: 'div', class: 'controls' do |input|
      input.wrapper tag: 'div', class: 'input-group' do |prepend|
        prepend.use :label, class: 'input-group-addon' # ##Please note setting class here fro the label does not currently work (let me know if you know a workaround as this is the final hurdle)
        prepend.use :input
      end
      input.use :hint,  wrap_with: { tag: 'span', class: 'help-block' }
      input.use :error, wrap_with: { tag: 'span', class: 'help-block has-error' }
    end
  end

  config.wrappers :append, tag: 'div', class: 'form-group', error_class: 'has-error' do |b|
    b.use :html5
    b.use :placeholder
    b.wrapper tag: 'div', class: 'controls' do |input|
      input.wrapper tag: 'div', class: 'input-group' do |prepend|
        prepend.use :input
        prepend.use :label, class: 'input-group-addon' # ##Please note setting class here fro the label does not currently work (let me know if you know a workaround as this is the final hurdle)
      end
      input.use :hint,  wrap_with: { tag: 'span', class: 'help-block' }
      input.use :error, wrap_with: { tag: 'span', class: 'help-block has-error' }
    end
  end

  config.wrappers :checkbox, tag: :div, class: 'checkbox', error_class: 'has-error' do |b|
    # Form extensions
    b.use :html5

    # Form components
    b.wrapper tag: :label do |ba|
      ba.use :input
      ba.use :label_text
    end

    b.use :hint,  wrap_with: { tag: :p, class: 'help-block' }
    b.use :error, wrap_with: { tag: :span, class: 'help-block text-danger' }
  end

  # Wrappers for forms and inputs using the Twitter Bootstrap toolkit.
  # Check the Bootstrap docs (http://getbootstrap.com/)
  # to learn about the different styles for forms and inputs,
  # buttons and other elements.
  # config.form_class = "form-horizontal"
  # config.label_class = "col-xs-2 col-sm-2 col-md-2 col-lg-2 control-label"
  # config.input_class = "form-control" #not yet supported
  # config.default_wrapper = :bootstrap

  config.wrappers :custom_boolean, tag: 'div', class: 'form-group', error_class: 'has-error', valid_class: 'has-success' do |b|
    b.use :html5
    b.optional :readonly
  
    b.wrapper :form_check_wrapper, tag: 'div', class: 'checkbox-inline' do |bb|
      bb.wrapper tag: 'label' do |bbb|
        bbb.use :input, class: 'checkbox-inline'
        bbb.use :label_text
      end
      bb.use :full_error, wrap_with: { tag: 'span', class: 'help-block' }
      bb.use :hint, wrap_with: { tag: 'p', class: 'help-block' }
    end
  end
  
  config.default_wrapper = :bootstrap3
end
