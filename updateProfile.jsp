<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.sql.*, java.net.URLEncoder" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String) session.getAttribute("currentUser");
    
    // 1. 로그인 체크 (세션이 없으면 로그인 페이지로)
    if (currentUser == null) {
        if (con != null) { try { con.close(); } catch (Exception ignore) {} }
        out.println("<script>alert('로그인이 필요합니다.'); location.href='login.jsp';</script>");
        return;
    }
    
    // POST 요청이 아니면 설정 페이지로 돌려보냄
    if (!"POST".equalsIgnoreCase(request.getMethod())) {
        if (con != null) { try { con.close(); } catch (Exception ignore) {} }
        response.sendRedirect("settings.jsp");
        return;
    }

    // 2. 파라미터 받기 (settings.jsp의 form 필드 이름과 일치해야 함)
    String address = request.getParameter("address");
    String phone = request.getParameter("phone");
    String status = request.getParameter("status_message"); // settings.jsp의 필드명에 따라 수정될 수 있음

    if (address == null) address = "";
    if (phone == null) phone = "";
    if (status == null) status = "";
    
    address = address.trim();
    phone = phone.trim();
    status = status.trim();

    String msg = "프로필 정보가 성공적으로 업데이트되었습니다.";
    boolean success = true;
    
    PreparedStatement ps = null;
    try {
        // 3. DB 업데이트 SQL
        // DB의 users 테이블에 'address', 'phone_number', 'status_message' 컬럼이 있다고 가정합니다.
        String sql = 
            "UPDATE users SET " +
            "  address = ?, " +
            "  phone_number = ?, " +
            "  status_message = ? " +
            "WHERE user_id = ?";
        
        ps = con.prepareStatement(sql);
        ps.setString(1, address.isEmpty() ? null : address);
        ps.setString(2, phone.isEmpty() ? null : phone);
        ps.setString(3, status.isEmpty() ? null : status);
        ps.setString(4, currentUser);
        
        int updatedRows = ps.executeUpdate();
        
        if (updatedRows == 0) {
            // 업데이트된 행이 없으면 사용자 ID 오류
            success = false;
            msg = "오류: 현재 로그인된 사용자를 찾을 수 없습니다.";
        }
        
    } catch (Exception e) {
        e.printStackTrace();
        success = false;
        msg = "프로필 업데이트 중 데이터베이스 오류가 발생했습니다: " + e.getMessage();
    } finally {
        if (ps != null) try { ps.close(); } catch (Exception ignore) {}
        if (con != null) try { con.close(); } catch (Exception ignore) {}
    }

    // 4. 결과 메시지를 포함하여 settings.jsp로 리다이렉트
    String encodedMsg = URLEncoder.encode(msg, "UTF-8");
    String redirectUrl = "settings.jsp?update_success=" + success + "&msg=" + encodedMsg;
    
    response.sendRedirect(redirectUrl);
%>