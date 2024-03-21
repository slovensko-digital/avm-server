class ErrorsController < ApplicationController
  def bad_request
    render json: {
      code: "BAD_REQUEST",
      message: "Bad request"
    },status: 400
  end

  def internal_error
    render json: {
      code: "INTERNAL_ERROR",
      message: "Unexpected error happened.",
      details: "If you are a maintainer of this server instance see logs for more information."
    }, status: 500
  end
end