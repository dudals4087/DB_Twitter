<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.io.*, java.util.*, java.sql.*" %>
<%@ page import="jakarta.servlet.http.Part" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");
    String currentUser = (String) session.getAttribute("currentUser");

    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    // 1. 저장 경로 설정
    String savePath = application.getRealPath("/uploads");
    File saveDir = new File(savePath);
    if (!saveDir.exists()) {
        saveDir.mkdirs(); // 폴더가 없으면 생성
    }

    try {
        // 2. 업로드된 파일 파트 가져오기 (name="profileImage")
        Part filePart = request.getPart("profileImage");
        String fileName = null;

        if (filePart != null && filePart.getSize() > 0) {
            // 파일명 추출 로직
            String contentDisp = filePart.getHeader("content-disposition");
            String[] tokens = contentDisp.split(";");
            for (String token : tokens) {
                if (token.trim().startsWith("filename")) {
                    fileName = token.substring(token.indexOf("=") + 2, token.length() - 1);
                }
            }
            
            // 파일명 중복 방지를 위해 시간 추가 (선택사항, 여기선 단순화)
            // 실제 저장 (Stream 방식 사용 - 호환성 좋음)
            if (fileName != null && !fileName.isEmpty()) {
                File file = new File(savePath, fileName);
                try (InputStream input = filePart.getInputStream();
                     OutputStream output = new FileOutputStream(file)) {
                    byte[] buffer = new byte[1024];
                    int length;
                    while ((length = input.read(buffer)) > 0) {
                        output.write(buffer, 0, length);
                    }
                }

                // 3. DB 업데이트
                String sql = "UPDATE users SET profile_img = ? WHERE user_id = ?";
                try (PreparedStatement ps = con.prepareStatement(sql)) {
                    ps.setString(1, fileName);
                    ps.setString(2, currentUser);
                    ps.executeUpdate();
                }
            }
        }
        
        // 처리가 끝나면 다시 설정 페이지로 돌아감
        response.sendRedirect("settings.jsp");

    } catch (Exception e) {
        e.printStackTrace();
        %>
        <script>
            alert("이미지 업로드 중 오류가 발생했습니다: <%= e.getMessage() %>");
            history.back();
        </script>
        <%
    } finally {
        if(con != null) try { con.close(); } catch(Exception e){}
    }
%>